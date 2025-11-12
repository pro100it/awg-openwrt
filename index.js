const axios = require('axios');
const cheerio = require('cheerio');
const core = require('@actions/core');

const version = process.argv[2];
const filterTargetsStr = process.argv[3] || '';
const filterSubtargetsStr = process.argv[4] || '';

const filterTargets = filterTargetsStr ? filterTargetsStr.split(',').map(t => t.trim()).filter(t => t) : [];
const filterSubtargets = filterSubtargetsStr ? filterSubtargetsStr.split(',').map(s => s.trim()).filter(s => s) : [];

console.log(`🔧 Starting configuration generation`);
console.log(`Version: ${version}`);
console.log(`Target filters: [${filterTargets.join(', ')}]`);
console.log(`Subtarget filters: [${filterSubtargets.join(', ')}]`);

if (!version) {
  core.setFailed('Version argument is required');
  process.exit(1);
}

let baseUrl;
if (version === 'snapshots') {
  baseUrl = 'https://downloads.openwrt.org/snapshots';
} else {
  baseUrl = `https://downloads.openwrt.org/releases/${version}`;
}

const targetsUrl = `${baseUrl}/targets/`;

async function fetchHTML(url) {
  try {
    console.log(`🌐 Fetching: ${url}`);
    const { data } = await axios.get(url);
    return cheerio.load(data);
  } catch (error) {
    console.error(`❌ Failed to fetch ${url}: ${error.message}`);
    throw error;
  }
}

async function getTargets() {
  try {
    const $ = await fetchHTML(targetsUrl);
    const targets = [];
    $('table tr td.n a').each((index, element) => {
      const name = $(element).attr('href');
      if (name && name.endsWith('/')) {
        targets.push(name.slice(0, -1));
      }
    });
    console.log(`🎯 Found targets: ${targets.join(', ')}`);
    return targets;
  } catch (error) {
    console.error(`❌ Failed to get targets from ${targetsUrl}`);
    return [];
  }
}

async function getSubtargets(target) {
  try {
    const $ = await fetchHTML(`${targetsUrl}${target}/`);
    const subtargets = [];
    $('table tr td.n a').each((index, element) => {
      const name = $(element).attr('href');
      if (name && name.endsWith('/')) {
        subtargets.push(name.slice(0, -1));
      }
    });
    console.log(`  📍 Found subtargets for ${target}: ${subtargets.join(', ')}`);
    return subtargets;
  } catch (error) {
    console.error(`  ❌ Failed to get subtargets for ${target}`);
    return [];
  }
}

async function getDetails(target, subtarget) {
  const packagesUrl = `${targetsUrl}${target}/${subtarget}/packages/`;
  const subtargetRootUrl = `${targetsUrl}${target}/${subtarget}/`;

  let vermagic = '';
  let pkgarch = '';

  try {
    // Пробуем папку packages
    const $packages = await fetchHTML(packagesUrl);
    $packages('a').each((index, element) => {
      const name = $(element).attr('href');
      if (name && name.startsWith('kernel_')) {
        const vermagicMatch = name.match(/kernel_\d+\.\d+\.\d+(?:-\d+)?[-~]([a-f0-9]+)(?:-r\d+)?_([a-zA-Z0-9_-]+)\.(?:ipk|apk)$/);
        if (vermagicMatch) {
          vermagic = vermagicMatch[1];
          pkgarch = vermagicMatch[2];
          console.log(`    ✅ Found pkgarch in packages/: ${pkgarch}`);
        }
      }
    });
  } catch (e) {
    // Игнорируем 404 для packages
  }

  if (!pkgarch) {
    try {
      // Пробуем корень subtarget
      const $root = await fetchHTML(subtargetRootUrl);
      $root('a').each((index, element) => {
        const name = $(element).attr('href');
        if (name && name.startsWith('kernel_')) {
          const vermagicMatch = name.match(/kernel_\d+\.\d+\.\d+(?:-\d+)?[-~]([a-f0-9]+)(?:-r\d+)?_([a-zA-Z0-9_-]+)\.(?:ipk|apk)$/);
          if (vermagicMatch) {
            vermagic = vermagicMatch[1];
            pkgarch = vermagicMatch[2];
            console.log(`    ✅ Found pkgarch in root: ${pkgarch}`);
          }
        }
      });
    } catch (e) {
      console.error(`    ❌ Failed to get details for ${target}/${subtarget}`);
    }
  }

  return { vermagic, pkgarch };
}

async function main() {
  try {
    const targets = await getTargets();
    const jobConfig = [];

    // Если указаны фильтры, но ничего не найдено - создаем дефолтную конфигурацию
    if (targets.length === 0 && filterTargets.length > 0) {
      console.log(`⚠️ No targets found, using filter targets directly`);
      for (const target of filterTargets) {
        for (const subtarget of filterSubtargets) {
          console.log(`🔧 Creating manual config for: ${target}/${subtarget}`);
          jobConfig.push({
            tag: version,
            target,
            subtarget,
            vermagic: 'manual',
            pkgarch: 'aarch64_cortex-a53', // Дефолтная архитектура для mediatek/filogic
          });
        }
      }
    } else {
      // Обычная обработка
      for (const target of targets) {
        if (filterTargets.length > 0 && !filterTargets.includes(target)) {
          console.log(`⏩ Skipping ${target} (filtered out)`);
          continue;
        }

        const subtargets = await getSubtargets(target);
        for (const subtarget of subtargets) {
          if (filterSubtargets.length > 0 && !filterSubtargets.includes(subtarget)) {
            console.log(`⏩ Skipping ${target}/${subtarget} (filtered out)`);
            continue;
          }

          console.log(`🔍 Processing: ${target}/${subtarget}`);
          const { vermagic, pkgarch } = await getDetails(target, subtarget);

          if (pkgarch) {
            jobConfig.push({
              tag: version,
              target,
              subtarget,
              vermagic,
              pkgarch,
            });
            console.log(`✅ Added ${target}/${subtarget} (${pkgarch})`);
          } else {
            console.log(`⚠️ Skipping ${target}/${subtarget} (no pkgarch found)`);
          }
        }
      }
    }

    console.log(`📊 Generated ${jobConfig.length} build configurations`);
    
    if (jobConfig.length === 0) {
      console.log('❌ No build configurations generated');
      core.setFailed('No build configurations generated. Check target/subtarget filters.');
      process.exit(1);
    }

    core.setOutput('job-config', JSON.stringify(jobConfig));
    console.log('🎉 Successfully generated job configuration');

  } catch (error) {
    console.error('💥 Fatal error:', error.message);
    core.setFailed(error.message);
    process.exit(1);
  }
}

main();