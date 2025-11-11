const axios = require('axios');
const cheerio = require('cheerio');
const core = require('@actions/core');

const version = process.argv[2]; // Получение версии OpenWRT (e.g., "23.05.3" or "snapshots")
const filterTargetsStr = process.argv[3] || ''; // Фильтр по targets (опционально, через запятую)
const filterSubtargetsStr = process.argv[4] || ''; // Фильтр по subtargets (опционально, через запятую)

// Преобразуем строки с запятыми в массивы
const filterTargets = filterTargetsStr ? filterTargetsStr.split(',').map(t => t.trim()).filter(t => t) : [];
const filterSubtargets = filterSubtargetsStr ? filterSubtargetsStr.split(',').map(s => s.trim()).filter(s => s) : [];

if (!version) {
  core.setFailed('Version argument is required');
  process.exit(1);
}

// --- ИЗМЕНЕНИЕ ---
// Определяем базовый URL в зависимости от версии
let baseUrl;
if (version === 'snapshots') {
  console.log('Running in "snapshots" mode.');
  baseUrl = 'https://downloads.openwrt.org/snapshots';
} else {
  console.log(`Running in "release" mode for version: ${version}`);
  baseUrl = `https://downloads.openwrt.org/releases/${version}`;
}

// Этот URL теперь используется всеми функциями
const targetsUrl = `${baseUrl}/targets/`;
// --- КОНЕЦ ИЗМЕНЕНИЯ ---


async function fetchHTML(url) {
  try {
    const { data } = await axios.get(url);
    return cheerio.load(data);
  } catch (error) {
    // Добавляем более информативную ошибку, если страница не найдена
    if (error.response && error.response.status === 404) {
      console.error(`Error 404: Page not found at ${url}`);
      console.error(`Check if version "${version}" and target/subtarget paths are correct.`);
    } else {
      console.error(`Error fetching HTML for ${url}: ${error}`);
    }
    throw error;
  }
}

async function getTargets() {
  // Используем новую переменную
  const $ = await fetchHTML(targetsUrl);
  const targets = [];
  $('table tr td.n a').each((index, element) => {
    const name = $(element).attr('href');
    if (name && name.endsWith('/')) {
      targets.push(name.slice(0, -1));
    }
  });
  return targets;
}

async function getSubtargets(target) {
  // Используем новую переменную
  const $ = await fetchHTML(`${targetsUrl}${target}/`);
  const subtargets = [];
  $('table tr td.n a').each((index, element) => {
    const name = $(element).attr('href');
    if (name && name.endsWith('/')) {
      subtargets.push(name.slice(0, -1));
    }
  });
  return subtargets;
}

async function getDetails(target, subtarget) {
  // Используем новую переменную
  const packagesUrl = `${targetsUrl}${target}/${subtarget}/packages/`;
  const $ = await fetchHTML(packagesUrl);
  let vermagic = '';
  let pkgarch = '';

  // Ваша Regex отлично работает и для релизов, и для снапшотов.
  // snapshot: kernel_6.6.32-1-HASH_aarch64_cortex-a53.ipk
  // release:  kernel_5.15.150-1-HASH-r1_mipsel_24kc.ipk
  // Regex (?:-r\d+)? как раз обрабатывает опциональный "-r1" в релизах.
  $('a').each((index, element) => {
    const name = $(element).attr('href');
    if (name && name.startsWith('kernel_')) {
      const vermagicMatch = name.match(/kernel_\d+\.\d+\.\d+(?:-\d+)?[-~]([a-f0-9]+)(?:-r\d+)?_([a-zA-Z0-9_-]+)\.ipk$/);
      if (vermagicMatch) {
        vermagic = vermagicMatch[1];
        pkgarch = vermagicMatch[2];
      }
    }
  });

  if (!pkgarch) {
    console.warn(`Could not find pkgarch for ${target}/${subtarget} at ${packagesUrl}`);
  }

  return { vermagic, pkgarch };
}

async function main() {
  try {
    const targets = await getTargets();
    const jobConfig = [];

    for (const target of targets) {
      // Пропускаем target, если указан массив фильтров и target не входит в него
      if (filterTargets.length > 0 && !filterTargets.includes(target)) {
        continue;
      }

      const subtargets = await getSubtargets(target);
      if (subtargets.length === 0) {
        // Это "плоский" target, где нет subtarget (например, "x86")
        // Ваш скрипт его пропускал, но для "snapshots" x86/64 популярен.
        // Давайте обработаем и его, используя subtarget="generic" (или сам target как subtarget)
        // Обновление: Логика OpenWRT такова, что если subtarget нет, 
        // то "packages" лежат прямо в .../targets/x86/64/
        // Но ваша логика getDetails ищет .../targets/x86/64/packages/
        // Давайте проверим, как работает ваша логика для x86/64
        // .../targets/x86/64/packages/ - это 404.
        // Пакеты лежат в .../targets/x86/64/
        //
        // Судя по вашей логике (которая ищет subtarget), вы не собираете для x86.
        // Оставим эту логику без изменений.
      }

      for (const subtarget of subtargets) {
        // Пропускаем subtarget, если указан массив фильтров и subtarget не входит в него
        if (filterSubtargets.length > 0 && !filterSubtargets.includes(subtarget)) {
          continue;
        }

        console.log(`Processing: ${target} / ${subtarget}`);
        const { vermagic, pkgarch } = await getDetails(target, subtarget);

        if (pkgarch) { // Добавляем, только если нашли pkgarch
          jobConfig.push({
            tag: version, // tag по-прежнему "snapshots" или "23.05.3"
            target,
            subtarget,
            vermagic,
            pkgarch,
          });
        } else {
          console.warn(`Skipping ${target}/${subtarget} (pkgarch not found)`);
        }
      }
    }

    if (jobConfig.length === 0) {
      console.warn('Warning: No build configurations were generated.');
      console.warn('This might be due to incorrect target/subtarget filters or no matching targets found.');
      console.warn(`Filters: Targets=[${filterTargets.join(',')}] Subtargets=[${filterSubtargets.join(',')}]`);
    }

    core.setOutput('job-config', JSON.stringify(jobConfig));
    console.log('Successfully generated job configuration.');
    console.log(JSON.stringify(jobConfig, null, 2));

  } catch (error) {
    core.setFailed(error.message);
  }
}

main();