<template>
  <div :class="`item-icon wrapper-${size}`">
    <!-- Font-Awesome Icon -->
    <i v-if="iconType === 'font-awesome'" :class="`${icon} ${size}`" ></i>
    <!-- Emoji Icon -->
    <i v-else-if="iconType === 'emoji'" :class="`emoji-icon ${size}`" >{{getEmoji(iconPath)}}</i>
    <!-- Material Design Icon -->
    <span v-else-if="iconType === 'mdi'" :class=" `mdi ${icon} ${size}`"></span>
    <!-- Simple-Icons -->
    <svg v-else-if="iconType === 'si'" :class="`simple-icons ${size}`"
      role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
      <path :d="getSimpleIcon(icon)" />
    </svg>
    <!-- Standard image asset icon -->
    <img v-else-if="iconPath" :src="iconPath"
      @error="imageNotFound"
      :class="`tile-icon ${size}`"
    />
    <!-- Removed BrokenImage - we now always fallback to generative icon instead -->
  </div>
</template>

<script>
// BrokenImage removed - now using generative icon fallback
import ErrorHandler from '@/utils/ErrorHandler';
import EmojiUnicodeRegex from '@/utils/EmojiUnicodeRegex';
import emojiLookup from '@/utils/emojis.json';
import {
  faviconApi as defaultFaviconApi, faviconApiEndpoints, iconCdns,
} from '@/utils/defaults';

const simpleicons = require('simple-icons');

export default {
  name: 'Icon',
  props: {
    icon: String, // Path to icon asset
    url: String, // Used for fetching the favicon
    size: String, // Either small, medium or large
    label: String, // Item title for generative icons
  },
  components: {},
  computed: {
    /* Get appConfig from store */
    appConfig() {
      return this.$store.getters.appConfig;
    },
    /* 保持原始 icon 值：如果配置了就用配置的，否则为空 */
    effectiveIcon() {
      // 只有明确配置了 icon 才使用，不再自动添加 'favicon'
      return this.icon || '';
    },
    /* Determines the type of icon */
    iconType() {
      return this.determineImageType(this.effectiveIcon);
    },
    /* Gets the icon path, dependent on icon type */
    iconPath() {
      return this.getIconPath(this.effectiveIcon, this.url);
    },
  },
  data() {
    return {
      fallbackStage: 0, // 0: Initial, 1: 备用API, 2: 生成图标
    };
  },
  methods: {
    /* Determine icon type, e.g. local or remote asset, SVG, favicon, font-awesome, etc */
    determineImageType(img) {
      let imgType = '';
      if (!img) imgType = 'auto-fetch'; // 没有配置icon时自动获取
      else if (this.isUrl(img)) imgType = 'url';
      else if (this.isImage(img)) imgType = 'img';
      else if (img.includes('fa-')) imgType = 'font-awesome';
      else if (img.includes('mdi-')) imgType = 'mdi';
      else if (img.includes('si-')) imgType = 'si';
      else if (img.includes('hl-')) imgType = 'home-lab-icons';
      else if (img.includes('sh-')) imgType = 'selfhst-icons';
      else if (img.includes('favicon-')) imgType = 'custom-favicon';
      else if (img === 'favicon') imgType = 'favicon';
      else if (img === 'generative') imgType = 'generative';
      else if (this.isEmoji(img).isEmoji) imgType = 'emoji';
      else imgType = 'auto-fetch'; // 无法识别时也尝试自动获取
      return imgType;
    },
    /* Return the path to icon asset, depending on icon type */
    getIconPath(img, url) {
      // 简化的 Fallback 策略：最多尝试2次 (默认API + 备用API)，然后生成图标
      const MAX_FALLBACK = 2;

      // 最终 Fallback: 生成图标
      if (this.fallbackStage >= MAX_FALLBACK) {
        return this.getGenerativeIcon(url || this.label || 'Web');
      }

      // 第一次失败后，尝试备用 API
      if (this.fallbackStage === 1) {
        // 使用一个可靠的备用 API (国内优先使用 wuruihong)
        const backupApi = 'wuruihong';
        const userDefault = this.appConfig.faviconApi || defaultFaviconApi;
        // 如果备用和默认相同，直接生成图标
        if (backupApi === userDefault) {
          return this.getGenerativeIcon(url || this.label || 'Web');
        }
        return this.getFavicon(url, backupApi);
      }

      // Initial Stage: 根据 icon 类型处理
      switch (this.determineImageType(img)) {
        case 'url': return img; // 直接使用配置的 URL
        case 'img': return this.getLocalImagePath(img);
        case 'favicon': return this.getFavicon(url);
        case 'custom-favicon': return this.getCustomFavicon(url, img);
        case 'generative': return this.getGenerativeIcon(url || this.label);
        case 'mdi': return img;
        case 'simple-icons': return this.getSimpleIcon(img);
        case 'home-lab-icons': return this.getHomeLabIcon(img);
        case 'selfhst-icons': return this.getSelfhstIcon(img);
        case 'svg': return img;
        case 'emoji': return img;
        case 'auto-fetch':
          // 没有配置 icon 时，尝试用 API 获取 favicon
          if (url && url.includes('http')) {
            return this.getFavicon(url);
          }
          // 无有效 URL 则直接生成
          return this.getGenerativeIcon(this.label || 'Web');
        default:
          return this.getGenerativeIcon(url || this.label || 'L');
      }
    },
    /* Check if a string is in a URL format. Used to identify tile icon source */
    isUrl(str) {
      const pattern = new RegExp(/(http|https):\/\/(\w+:{0,1}\w*)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%!\-/]))?/);
      return pattern.test(str);
    },
    /* Returns true if the input is a path to an image file */
    isImage(img) {
      const fileExtRegex = /(?:\.([^.]+))?$/;
      const validImgExtensions = ['svg', 'png', 'jpg'];
      const splitPath = fileExtRegex.exec(img);
      if (splitPath.length >= 1) return validImgExtensions.includes(splitPath[1]);
      return false;
    },
    /* Determines if a given string is an emoji, and if so what type it is */
    isEmoji(img) {
      if (EmojiUnicodeRegex.test(img) && img.match(/./gu).length) { // Is a unicode emoji
        return { isEmoji: true, emojiType: 'glyph' };
      } else if (new RegExp(/^:.*:$/).test(img)) { // Is a shortcode emoji
        return { isEmoji: true, emojiType: 'shortcode' };
      } else if (img.substring(0, 2) === 'U+' && img.length === 7) {
        return { isEmoji: true, emojiType: 'unicode' };
      }
      return { isEmoji: false, emojiType: '' };
    },
    /* Returns the corresponding emoji for a shortcode, or shows error if not found */
    getShortCodeEmoji(emojiCode) {
      if (emojiLookup[emojiCode]) {
        return emojiLookup[emojiCode];
      } else {
        // this.imageNotFound(`No emoji found with name '${emojiCode}'`);
        return null;
      }
    },
    /* Formats and gets emoji from either unicode, shortcode or glyph */
    getEmoji(emojiCode) {
      const { emojiType } = this.isEmoji(emojiCode);
      if (emojiType === 'shortcode') { // Short code emoji
        return this.getShortCodeEmoji(emojiCode);
      } else if (emojiType === 'unicode') { // Unicode emoji
        return String.fromCodePoint(parseInt(emojiCode.substr(2), 16));
      } else if (emojiType === 'glyph') { // Emoji is a glyph
        return emojiCode;
      }
      this.imageNotFound(`Unrecognized emoji: '${emojiCode}'`);
      return null;
    },
    /* Get favicon URL, for items which use the favicon as their icon */
    getFavicon(fullUrl, specificApi) {
      const fullUrlTrue = fullUrl || '';
      const faviconApi = specificApi || this.appConfig.faviconApi || defaultFaviconApi;

      // If specificApi is passed (e.g. 'google' from fallback), use it directly
      if (specificApi) {
        const host = this.getHostName(fullUrlTrue);
        const endpoint = faviconApiEndpoints[specificApi];
        return endpoint ? endpoint.replace('$URL', host) : '';
      }

      if (this.shouldUseDefaultFavicon(fullUrlTrue) || faviconApi === 'local') { // Check if we should use local icon
        const urlParts = fullUrlTrue.split('/');
        if (urlParts.length >= 2) return `${urlParts[0]}/${urlParts[1]}/${urlParts[2]}/${iconCdns.faviconName}`;
      } else if (fullUrlTrue.includes('http')) { // Service is running publicly
        const host = this.getHostName(fullUrlTrue);
        const endpoint = faviconApiEndpoints[faviconApi];
        return endpoint.replace('$URL', host);
      }
      return '';
    },
    /* Get the URL for a favicon, but using the non-default favicon API */
    getCustomFavicon(fullUrl, faviconIdentifier) {
      let errorMsg = '';
      const faviconApi = faviconIdentifier.split('favicon-')[1];
      if (!faviconApi) {
        errorMsg = 'Favicon API not specified';
      } else if (!Object.keys(faviconApiEndpoints).includes(faviconApi) && faviconApi !== 'local') {
        errorMsg = `The specified favicon API, '${faviconApi}' cannot be found.`;
      } else {
        return this.getFavicon(fullUrl, faviconApi);
      }
      // Error encountered, favicon service not found
      this.imageNotFound(errorMsg);
      return undefined;
    },
    /* If using favicon for icon, and if service is running locally (determined by local IP) */
    /* or if user prefers local favicon, then return true */
    shouldUseDefaultFavicon(fullUrl) {
      const isLocalIP = /(127\.)|(192\.168\.)|(10\.)|(172\.1[6-9]\.)|(172\.2[0-9]\.)|(172\.3[0-1]\.)|(::1$)|([fF][cCdD])|(localhost)/;
      return (isLocalIP.test(fullUrl) || this.appConfig.faviconApi === 'local');
    },
    /* Fetches the path of local images, from Docker container */
    getLocalImagePath(img) {
      return `/${iconCdns.localPath}/${img}`;
    },
    /* Generates a local SVG icon based on the URL/Title initials */
    getGenerativeIcon(url) {
      const host = this.getHostName(url) || this.label || url || 'Web';

      // Smart text extraction (supports Chinese and English)
      const text = this.extractInitials(host);

      // Generate gradient colors
      const [color1, color2] = this.generateGradientColors(host);

      const uniqueId = this.hashCode(host);
      const svg = `
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
          <defs>
            <linearGradient id="grad-${uniqueId}" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" style="stop-color:${color1};stop-opacity:1" />
              <stop offset="100%" style="stop-color:${color2};stop-opacity:1" />
            </linearGradient>
          </defs>
          <rect width="128" height="128" rx="20" fill="url(#grad-${uniqueId})"/>
          <text x="50%" y="52%" dominant-baseline="middle" text-anchor="middle" 
             font-family="Arial, -apple-system, BlinkMacSystemFont, 'Microsoft YaHei', sans-serif" 
             font-size="56" font-weight="700" fill="#fff" opacity="0.95">
            ${text}
          </text>
        </svg>
      `.trim();

      // Use btoa safely for UTF-8 (Chinese characters)
      const base64 = btoa(unescape(encodeURIComponent(svg)));
      return `data:image/svg+xml;base64,${base64}`;
    },
    /* Extract initials from string (supports Chinese and English) */
    extractInitials(str) {
      // Remove protocol, www, and non-alphanumeric chars (keep Chinese)
      let cleaned = str.replace(/^(https?:\/\/)?(www\.)?/, '');
      cleaned = cleaned.replace(/[^a-zA-Z0-9\u4e00-\u9fa5]/g, '');

      if (!cleaned) return 'W';

      const firstChar = cleaned.charAt(0).toUpperCase();
      const isChinese = /[\u4e00-\u9fa5]/.test(firstChar);

      if (isChinese) {
        // For Chinese, take 1 character
        return firstChar;
      } else {
        // For English, take 1-2 characters
        const match = cleaned.match(/^([a-zA-Z0-9]{1,2})/);
        return match ? match[0].toUpperCase() : 'W';
      }
    },
    /* Generate gradient colors based on string hash */
    generateGradientColors(str) {
      const hash = this.hashCode(str);
      const hue = Math.abs(hash % 360);

      // Generate vibrant, modern gradient colors
      const color1 = `hsl(${hue}, 70%, 55%)`;
      const color2 = `hsl(${(hue + 40) % 360}, 70%, 45%)`;

      return [color1, color2];
    },
    /* Generate hash code from string */
    hashCode(str) {
      let hash = 0;
      for (let i = 0; i < str.length; i += 1) {
        // eslint-disable-next-line no-bitwise
        hash = ((hash << 5) - hash) + str.charCodeAt(i);
        // eslint-disable-next-line no-bitwise
        hash |= 0;
      }
      return hash;
    },
    /* Returns the SVG path content  */
    getSimpleIcon(img) {
      const imageName = img.charAt(3).toUpperCase() + img.slice(4);
      const icon = simpleicons[`si${imageName}`];
      if (!icon) {
        this.imageNotFound(`No icon was found for '${imageName}' in Simple Icons`);
        return null;
      }
      return icon.path;
    },
    getSelfhstIcon(img, cdn) {
      const imageName = img.slice(3).toLocaleLowerCase();
      return (cdn || iconCdns.sh).replace('{icon}', imageName);
    },
    /* Gets home-lab icon from GitHub */
    getHomeLabIcon(img, cdn) {
      const imageName = img.replace('hl-', '').toLocaleLowerCase();
      return (cdn || iconCdns.homeLabIcons).replace('{icon}', imageName);
    },
    getHostName(url) {
      try {
        return new URL(url).hostname;
      } catch (e) {
        ErrorHandler('Unable to format URL');
        return url;
      }
    },
    /* Called when the path to the image cannot be resolved - 简化的 fallback 策略 */
    imageNotFound() {
      // 简化：只尝试一次备用 API，然后直接生成图标
      // 最多 2 阶段：0 → 1 (备用API) → 2 (生成图标)
      if (this.fallbackStage < 2) {
        this.fallbackStage += 1;
        // Vue 会自动重新计算 iconPath，触发新的图片请求
      }
      // 阶段 2 会由 getIconPath 处理，直接返回生成图标
    },
  },
};
</script>

<style lang="scss">

/* Icon wraper */
.item-icon {
  &.wrapper-medium {
    min-height: 2.5rem;
  }
  &.wrapper-large {
    min-width: 3.5rem;
    text-align: center;
  }
}

  /* Default Image Icon */
  .tile-icon {
      min-width: 1rem;
      max-width: 2rem;
      min-height: 1rem;
      max-height: 2rem;
      object-fit: cover;
      /* Smart icon enhancement: preserves colors while improving visibility */
      /* saturate enhances color vibrancy, brightness makes icons more visible on */
      /* dark backgrounds */
      filter: var(--item-icon-transform) saturate(1.2) brightness(var(--icon-brightness, 1.1));
      border-radius: var(--curve-factor);
      &.small {
        max-width: 1.5rem;
        max-height: 1.5rem;
      }
      &.large {
        max-width: 3rem;
        max-height: 3rem;
      }
      &.broken {
        display: none;
      }
  }
  /* Font-Awesome and Material Design Icons */
  i.fas, i.fab, i.far, i.fal, i.fad, span.mdi {
    font-size: 2rem;
    color: currentColor;
    margin: 1px 4px;
    &.small {
      font-size: 1.5rem;
    }
    &.large {
      font-size: 2.5rem;
    }
  }
  span.mdi {
    font-size: 2.5rem;
  }
  object.tile-icon {
    width: 55px;
    height: 55px;
    svg, svg g, svg g path {
      fill: currentColor;
    }
  }
  /* Simple Icons */
  .item-icon .simple-icons {
    width: 2rem;
    &.small { width: 1.5rem; }
    &.large { width: 2.5rem; }
  }

  .item-icon .simple-icons path {
    fill: currentColor;
  }
  /* Emoji Icons */
  i.emoji-icon {
    font-style: normal;
    font-size: 2rem;
    margin: 0.2rem;
    &.small {
      font-size: 1.5rem;
    }
    &.large {
      font-size: 2.5rem;
    }
  }
  /* Icon Not Found */
  .missing-image {
    width: 2rem;
    &.small {
      width: 1.5rem !important;
    }
    &.large {
      width: 2.5rem;
    }
    path {
      fill: currentColor;
    }
  }
</style>
