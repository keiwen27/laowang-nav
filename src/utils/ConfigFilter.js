/**
 * 过滤配置中与同步数据相同的条目
 * (Deployment Sync Mode: Remote fetching disabled)
 */

/**
 * 检查两个配置项是否相同
 * @param {Object} item1 - 第一个配置项
 * @param {Object} item2 - 第二个配置项
 * @returns {boolean} - 是否相同
 */
function isSameItem(item1, item2) {
  if (!item1 || !item2) return false;

  // 比较关键字段
  return item1.title === item2.title
    && item1.url === item2.url
    && item1.icon === item2.icon
    && item1.description === item2.description;
}

/**
 * 过滤掉与同步数据完全相同的分类和条目
 * @param {Object} config - 完整配置对象
 * @param {Array} syncedSections - 同步的分类数据
 * @returns {Object} - 过滤后的配置对象
 */
export function filterSyncedData(config, syncedSections) {
  if (!syncedSections || syncedSections.length === 0) {
    // 如果没有同步数据，返回原配置
    return config;
  }

  const filteredConfig = { ...config };
  const filteredSections = [];

  config.sections.forEach((section) => {
    const syncedSection = syncedSections.find((s) => s.name === section.name);

    if (!syncedSection) {
      // 完全自定义的分类，保留
      filteredSections.push(section);
      return;
    }

    // 分类存在于同步数据中，需要过滤条目
    const filteredItems = [];

    (section.items || []).forEach((item) => {
      const syncedItem = (syncedSection.items || []).find((si) => si.title === item.title);

      if (!syncedItem) {
        // 自定义的条目，保留
        filteredItems.push(item);
      } else if (!isSameItem(item, syncedItem)) {
        // 修改过的条目，保留
        filteredItems.push(item);
      }
      // 如果与同步数据完全相同，则不保留（被过滤掉）
    });

    // 如果分类有保留的条目，或者分类的其他属性被修改了，保留这个分类
    if (filteredItems.length > 0) {
      filteredSections.push({
        ...section,
        items: filteredItems,
      });
    } else {
      // 检查分类的其他属性（如icon）是否被修改
      const sectionModified = section.icon !== syncedSection.icon
        || section.displayData !== syncedSection.displayData;

      if (sectionModified) {
        // 分类属性被修改，保留分类结构但items为空
        filteredSections.push({
          ...section,
          items: [],
        });
      }
      // 否则整个分类都不保留
    }
  });

  filteredConfig.sections = filteredSections;
  return filteredConfig;
}

/**
 * 获取同步数据
 * @returns {Promise<Array>} - 同步的分类数据
 */
export async function getSyncedSections() {
  // Disabled remote sync based on user request (Deployment Sync Only)
  return [];
}
