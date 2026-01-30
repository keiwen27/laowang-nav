import {
  websiteDatabase,
  keywordPatterns,
} from './websiteDatabase';

class DescriptionGenerator {
  static generateDescription(url, title = '') {
    try {
      const hostname = new URL(url).hostname.replace(/^www\./, '');

      // 第一层：数据库查找
      const dbDesc = this.lookupDatabase(hostname);
      if (dbDesc) return { source: 'database', description: dbDesc };

      // 第二层：关键词匹配
      const keywordDesc = this.matchKeywords(hostname, title);
      if (keywordDesc) {
        return { source: 'keyword', description: keywordDesc };
      }

      // 兜底：使用标题或域名
      return {
        source: 'fallback',
        description: title || this.extractDomainName(hostname),
      };
    } catch (error) {
      return { source: 'error', description: title || '' };
    }
  }

  static lookupDatabase(hostname) {
    if (websiteDatabase[hostname]) {
      return websiteDatabase[hostname];
    }

    const entries = Object.entries(websiteDatabase);
    for (let i = 0; i < entries.length; i += 1) {
      const [domain, desc] = entries[i];
      if (hostname.includes(domain) || domain.includes(hostname)) {
        return desc;
      }
    }
    return null;
  }

  static matchKeywords(hostname, title) {
    const searchText = `${hostname} ${title}`.toLowerCase();

    for (let i = 0; i < keywordPatterns.length; i += 1) {
      const { pattern, description } = keywordPatterns[i];
      if (pattern.test(searchText)) return description;
    }
    return null;
  }

  static extractDomainName(hostname) {
    const parts = hostname.split('.');
    const main = parts[parts.length - 2] || parts[0];
    return main.charAt(0).toUpperCase() + main.slice(1);
  }
}

export default DescriptionGenerator;
