export const websiteDatabase = {
  'gmail.com': 'Google邮箱',
  'outlook.com': '微软Outlook邮箱',
  'github.com': '代码托管平台',
  'vercel.com': 'Vercel部署平台',
  'cloudflare.com': 'Cloudflare CDN',
  'openai.com': 'OpenAI ChatGPT',
  'claude.ai': 'Claude AI助手',
  'deepseek.com': 'DeepSeek AI',
  'youtube.com': 'YouTube视频',
  'google.com': '谷歌搜索',
  'baidu.com': '百度搜索',
};

export const keywordPatterns = [
  {
    pattern: /mail|email/,
    description: '邮箱服务',
  },
  {
    pattern: /sms/,
    description: '短信服务',
  },
  {
    pattern: /temp/,
    description: '临时服务',
  },
  {
    pattern: /cloud/,
    description: '云服务平台',
  },
  {
    pattern: /ai|gpt/,
    description: 'AI智能工具',
  },
  {
    pattern: /git|code/,
    description: '代码仓库',
  },
  {
    pattern: /domain/,
    description: '域名服务',
  },
];
