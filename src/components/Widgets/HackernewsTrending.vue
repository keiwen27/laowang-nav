<template>
<div class="hackernews-wrapper">
  <!-- Hackernews Trending Posts-->
  <div class="posts-wrapper" v-if="trendingPosts">
    <div class="post-row" v-for="(trendingPosts, index) in trendingPosts" :key="index">
      <a class="post-top" :href="trendingPosts.originURL">
        <div class="post-title-wrap">
          <p class="post-title">{{ trendingPosts.title }}</p>
            <p class="post-date">
              {{ formatDate(trendingPosts.time) }}
            </p>
            <p class="post-score" v-if="trendingPosts.score">score: {{ trendingPosts.score }}</p>
        </div>
      </a>
    </div>
  </div>
</div>
</template>

<script>
// import axios from 'axios';
import WidgetMixin from '@/mixins/WidgetMixin';
import { widgetApiEndpoints } from '@/utils/defaults';

export default {
  mixins: [WidgetMixin],
  data() {
    return {
      trendingPosts: null,
    };
  },
  computed: {
    stories() {
      // Valid story types supported by Hacker News API
      const validStories = ['beststories', 'topstories', 'newstories'];
      const userStory = this.options.stories || 'topstories';

      // Validate user input
      if (!validStories.includes(userStory)) {
        console.warn(
          `Invalid Hacker News story type: "${userStory}". `
          + `Valid options are: ${validStories.join(', ')}. Using 'topstories' instead.`,
        );
        return 'topstories';
      }

      return userStory;
    },
    limit() {
      return this.options.limit || 10;
    },
    endpoint() {
      return `${widgetApiEndpoints.hackernewsTrending}/${this.stories}.json`;
    },
  },
  methods: {
    fetchData() {
      this.makeRequest(this.endpoint).then(this.fetchPostDetails);
    },
    async fetchPostDetails(data) {
      const topPosts = data.slice(0, this.limit);
      const allData = topPosts.map((post) => {
        const url = `${widgetApiEndpoints.hackernewsTrending}/item/${post}.json`;
        return this.makeRequest(url);
      });
      Promise.all(allData).then((resolvedPostValues) => {
        this.trendingPosts = resolvedPostValues.map((element, index) => {
          const trendingPost = { ...element, originURL: `https://news.ycombinator.com/item?id=${topPosts.at(index)}` };
          return trendingPost;
        });
      });
    },
    formatDate(unixTime) {
      const date = new Date(unixTime * 1000);
      // Then specify how you want your dates to be formatted
      return new Intl.DateTimeFormat('default', { dateStyle: 'long' }).format(date);
    },
  },
};
</script>

<style scoped lang="scss">
.hackernews-wrapper {
 .meta-container {
    display: flex;
    align-items: center;
    text-decoration: none;
    margin: 0.25rem 0 0.5rem 0;
  }

  .post-row {
    border-top: 1px dashed var(--widget-text-color);
    padding: 0.5rem 0 0.25rem 0;
    .post-top {
      display: flex;
      align-items: center;
      text-decoration: none;
      p.post-title {
        margin: 0;
        font-size: 1rem;
        font-weight: bold;
        color: var(--widget-text-color);
      }
      p.post-date {
        font-size: 0.8rem;
        margin: 0;
        opacity: var(--dimming-factor);
        color: var(--widget-text-color);
      }
      p.post-score {
        font-size: 0.8rem;
        margin: 0;
        opacity: var(--dimming-factor);
        color: var(--widget-text-color);
      }
    }
  }
}
</style>
