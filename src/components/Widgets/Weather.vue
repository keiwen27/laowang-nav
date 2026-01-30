<template>
<div class="weather">
  <!-- Icon + Temperature -->
  <div class="intro">
    <div class="main-info">
      <p class="temp">{{ temp }}</p>
      <i :class="'owi owi-' + icon"></i>
    </div>
    <p class="location" v-if="location"> {{ location }}</p>
  </div>
  <!-- Weather description -->
  <p class="description">{{ description }}</p>
  <div class="details" v-if="showDetails && weatherDetails.length > 0">
    <div class="info-wrap" v-for="(section, indx) in weatherDetails" :key="indx">
      <p class="info-line" v-for="weather in section" :key="weather.label">
          <span class="lbl">{{weather.label}}</span>
          <span class="val">{{ weather.value }}</span>
        </p>
    </div>
  </div>
  <!-- Show/ hide toggle button -->
  <p class="more-details-btn" @click="toggleDetails" v-if="weatherDetails.length > 0">
    {{ showDetails ? ('widgets.general.show-less') : ('widgets.general.show-more') }}
  </p>
</div>
</template>

<script>
import WidgetMixin from '@/mixins/WidgetMixin';
import { widgetApiEndpoints } from '@/utils/defaults';

export default {
  mixins: [WidgetMixin],
  data() {
    return {
      loading: true,
      icon: '01d', // Default icon
      description: 'Loading...',
      temp: '--',
      location: '',
      showDetails: false,
      weatherDetails: [],
    };
  },
  mounted() {
    this.fetchSmartWeather();
  },
  computed: {
    units() { return this.options.units || 'metric'; },
    tempDisplayUnits() { return this.units === 'imperial' ? 'F' : 'C'; },
  },
  methods: {
    /* 主要入口：智能天气获取 */
    async fetchSmartWeather() {
      this.loading = true;
      let geo = null;

      // 1. 获取位置信息 (IP 定位)
      try {
        geo = await this.fetchLocation();
      } catch (e) {
        console.warn('Location detection failed, defaulting to global mode');
      }

      const isCN = geo && geo.country === 'CN';

      // 2. 根据地区选择策略
      if (isCN) {
        // --- 国内策略 (优先中文源) ---
        // Plan A: VVHan (韩小韩) - 速度快，原生中文
        if (await this.fetchVVHan()) {
          this.loading = false;
          return;
        }
        // Plan B: Oioweb - 备用中文源
        if (await this.fetchOioweb()) {
          this.loading = false;
          return;
        }
        // Plan C: Open-Meteo (使用 IP 经纬度)
        if (geo && geo.lat && geo.lon && await this.fetchOpenMeteo(geo.lat, geo.lon, true)) {
          this.loading = false;
          return;
        }
      } else {
        // --- 国际策略 ---
        // Plan A: Open-Meteo (最准，全球覆盖)
        if (geo && geo.lat && geo.lon && await this.fetchOpenMeteo(geo.lat, geo.lon, false)) {
          this.loading = false;
          return;
        }
        // Plan B: OpenWeatherMap (如果有 Key)
        if (this.options.apiKey && await this.fetchOWM()) {
          this.loading = false;
          return;
        }
      }

      // 3. 最后的兜底 (Wttr.in)
      await this.fetchWttr();
      this.loading = false;
    },

    /* 获取位置信息 */
    async fetchLocation() {
      try {
        // 尝试使用 ipapi.co (HTTPS, JSON)
        const res = await fetch('https://ipapi.co/json/');
        if (res.ok) {
          const data = await res.json();
          return {
            country: data.country_code, // e.g., 'CN', 'US'
            city: data.city,
            lat: data.latitude,
            lon: data.longitude,
          };
        }
      } catch (e) {
        console.warn('IPAPI failed, trying backup...');
      }
      return null;
    },

    /* --- 源 1: VVHan (适合国内) --- */
    async fetchVVHan() {
      try {
        const res = await fetch('https://api.vvhan.com/api/weather');
        const data = await res.json();
        if (data.success && data.info) {
          this.temp = `${data.info.high.replace('C', '')}C`; // 保持统一格式
          this.description = data.info.type; // 中文描述
          this.location = this.sanitizeLocation(data.city || '本地');
          this.icon = this.mapIcon(data.info.type);
          this.weatherDetails = [[
            { label: '低温', value: data.info.low },
            { label: '高温', value: data.info.high },
            { label: '风向', value: data.info.fengxiang },
          ]];
          return true;
        }
      } catch (e) { console.error('VVHan Error:', e); }
      return false;
    },

    /* --- 源 2: Oioweb (适合国内) --- */
    async fetchOioweb() {
      try {
        const res = await fetch('https://api.oioweb.cn/api/weather/weather');
        const data = await res.json();
        if (data.code === 200 && data.result) {
          const w = data.result;
          this.temp = `${w.current_temperature}C`;
          this.description = w.weather; // 中文
          this.location = this.sanitizeLocation(w.city_name);
          this.icon = this.mapIcon(w.weather);
          this.weatherDetails = [[
            { label: '最高', value: `${w.high_temperature}C` },
            { label: '最低', value: `${w.low_temperature}C` },
            { label: '风向', value: w.wind_direction },
          ]];
          return true;
        }
      } catch (e) { console.error('Oioweb Error:', e); }
      return false;
    },

    /* --- 源 3: Open-Meteo (全球推荐) --- */
    async fetchOpenMeteo(lat, lon, isCN) {
      try {
        const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,weather_code,relative_humidity_2m,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min&timezone=auto`;
        const res = await fetch(url);
        const data = await res.json();

        if (data.current) {
          this.temp = `${Math.round(data.current.temperature_2m)}C`;
          const code = data.current.weather_code;
          this.description = this.mapWmoCode(code, isCN);
          this.icon = this.mapWmoIcon(code);
          // Open-Meteo 不返回城市名，显示经纬度坐标更有用
          if (isCN) {
            // 中国用户显示经纬度，比"本地气象"更有信息量
            this.location = `${Math.abs(lat).toFixed(1)}°${lat >= 0 ? 'N' : 'S'}, ${Math.abs(lon).toFixed(1)}°${lon >= 0 ? 'E' : 'W'}`;
          } else {
            this.location = 'Local Weather';
          }

          this.weatherDetails = [[
            { label: isCN ? '湿度' : 'Humidity', value: `${data.current.relative_humidity_2m}%` },
            { label: isCN ? '风速' : 'Wind', value: `${data.current.wind_speed_10m} km/h` },
            { label: isCN ? '最高' : 'Max', value: `${Math.round(data.daily.temperature_2m_max[0])}C` },
          ]];
          return true;
        }
      } catch (e) { console.error('OpenMeteo Error:', e); }
      return false;
    },

    /* --- 源 4: OpenWeatherMap (Legacy) --- */
    async fetchOWM() {
      // ... (保持原有逻辑作为备用) ...
      try {
        const apiKey = this.parseAsEnvVar(this.options.apiKey);
        const { city } = this.options;
        if (!apiKey) return false;

        const params = `q=${city || 'Beijing'}&appid=${apiKey}&units=${this.units}`;
        const url = `${widgetApiEndpoints.weather}?${params}`;
        const res = await fetch(url);
        const data = await res.json();
        if (data.cod === 200) {
          this.processOWMData(data);
          return true;
        }
      } catch (e) { /* ignore */ }
      return false;
    },

    /* --- 源 5: Wttr.in (兜底) --- */
    async fetchWttr() {
      try {
        const res = await fetch('https://wttr.in/?format=j1');
        const data = await res.json();
        const current = data.current_condition[0];
        const area = data.nearest_area[0];

        // 尝试简单的中文映射（Wttr返回是英文）
        this.temp = `${current.temp_C}C`;
        this.description = current.weatherDesc[0].value;
        this.location = this.sanitizeLocation(area.areaName?.[0]?.value || 'Unknown');
        this.icon = '01d';
      } catch (e) {
        this.description = 'Service N/A';
        this.location = 'Offline';
      }
    },

    /* 辅助：Open-Meteo WMO Code 映射 */
    mapWmoCode(code, isCN) {
      const map = {
        0: ['Clear sky', '晴'],
        1: ['Mainly clear', '多云'],
        2: ['Partly cloudy', '多云'],
        3: ['Overcast', '阴'],
        45: ['Fog', '雾'],
        48: ['Depositing rime fog', '雾凇'],
        51: ['Light drizzle', '小毛毛雨'],
        53: ['Drizzle', '毛毛雨'],
        55: ['Heavy drizzle', '大毛毛雨'],
        61: ['Light rain', '小雨'],
        63: ['Rain', '中雨'],
        65: ['Heavy rain', '大雨'],
        71: ['Light snow', '小雪'],
        73: ['Snow', '中雪'],
        75: ['Heavy snow', '大雪'],
        95: ['Thunderstorm', '雷雨'],
      };

      const entry = map[code] || ['Unknown', '未知'];
      return isCN ? entry[1] : entry[0];
    },

    mapWmoIcon(code) {
      // 简单映射到 OWI 图标
      if (code === 0) return '01d';
      if (code >= 1 && code <= 3) return '02d';
      if (code >= 45 && code <= 48) return '50d';
      if (code >= 51 && code <= 67) return '09d';
      if (code >= 71 && code <= 77) return '13d';
      if (code >= 95) return '11d';
      return '01d';
    },

    /* 通用文字转图标映射 (用于中文 API) */
    mapIcon(condition) {
      if (!condition) return '01d';
      const c = condition.toString();
      if (c.includes('晴')) return '01d';
      if (c.includes('云') || c.includes('阴')) return '02d';
      if (c.includes('雨')) return '09d';
      if (c.includes('雪')) return '13d';
      if (c.includes('雷')) return '11d';
      if (c.includes('雾') || c.includes('霾')) return '50d';
      return '01d';
    },

    processOWMData(data) {
      this.icon = data.weather[0].icon;
      this.description = data.weather[0].description;
      this.temp = Math.round(data.main.temp) + this.tempDisplayUnits;
      this.location = this.sanitizeLocation(data.name);
      if (!this.options.hideDetails) {
        this.makeOWMDetails(data);
      }
    },

    makeOWMDetails(data) {
      this.weatherDetails = [
        [
          { label: 'Min', value: Math.round(data.main.temp_min) + this.tempDisplayUnits },
          { label: 'Max', value: Math.round(data.main.temp_max) + this.tempDisplayUnits },
          { label: 'Feels', value: Math.round(data.main.feels_like) + this.tempDisplayUnits },
        ],
        [
          { label: 'Hum', value: ` ${data.main.humidity}%` },
          { label: 'Wind', value: ` ${data.wind.speed}m/s` },
        ],
      ];
    },

    /* 过滤不合理的地名 */
    sanitizeLocation(location) {
      if (!location) return '';

      // 1. 过滤 emoji 占位符 (:coffee:, :unknown: 等)
      if (typeof location === 'string'
          && location.startsWith(':')
          && location.endsWith(':')) {
        return '';
      }

      // 2. 过滤明确的无效值（使用完全匹配，避免误伤真实地名）
      const invalidNames = ['Unknown', 'undefined', 'null', 'N/A', 'Invalid'];
      const normalizedLocation = location.toLowerCase().trim();

      if (invalidNames.some(n => normalizedLocation === n.toLowerCase())) {
        return '';
      }

      // 3. 返回清理后的地名
      return location.trim();
    },

    toggleDetails() { this.showDetails = !this.showDetails; },
  },
};
</script>

<style scoped lang="scss">
@import '@/styles/weather-icons.scss';

.loader {
  margin: 0 auto;
  display: flex;
}
  p {
    color: var(--widget-text-color);
  }

.weather {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  // Weather symbol and temperature
  .intro {
    grid-column-start: span 2;
    display: flex;
    flex-direction: column;
    align-items: center;

    .main-info {
      display: flex;
      justify-content: space-around;
      width: 100%;
      align-items: center;

      .owi {
        font-size: 3rem;
        color: var(--widget-text-color);
        margin: 0;
      }
      .temp {
        font-size: 3rem;
        margin: 0;
      }
    }

    .location {
      margin: 0.2rem 0 0 0;
      font-size: 0.9rem;
      opacity: 0.8;
      color: var(--widget-text-color);
    }
  }
  // Weather description
  .description {
    grid-column-start: 2;
    text-transform: capitalize;
    text-align: center;
    margin: 0;
  }
  // Show more details button
  .more-details-btn {
    grid-column-start: span 2;
    cursor: pointer;
    font-size: 0.9rem;
    text-align: center;
    width: fit-content;
    margin: 0.25rem auto;
    padding: 0.1rem 0.25rem;
    border: 1px solid transparent;
    opacity: var(--dimming-factor);
    border-radius: var(--curve-factor);
    &:hover {
      border: 1px solid var(--widget-text-color);
    }
    &:focus, &:active {
      background: var(--widget-text-color);
      color: var(--widget-background-color);
    }
  }
  // More weather details table
  .details {
    grid-column-start: span 2;
    display: flex;
    .info-wrap {
      display: flex;
      flex-direction: column;
      width: 100%;
      opacity: var(--dimming-factor);
      p.info-line {
        display: flex;
        justify-content: space-between;
        margin: 0.1rem 0.5rem;
        padding: 0.1rem 0;
        color: var(--widget-text-color);
        &:not(:last-child) {
          border-bottom: 1px dashed var(--widget-text-color);
        }
        span.lbl {
          text-transform: capitalize;
        }
      }
    }
  }
}

</style>
