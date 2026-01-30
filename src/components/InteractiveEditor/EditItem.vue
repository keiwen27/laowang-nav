<template>
  <modal
    :name="modalName"
    :resizable="true"
    width="50%"
    height="80%"
    classes="laowang-modal edit-item"
    @closed="modalClosed"
  >
  <div class="edit-item-inner" v-if="allowViewConfig">
    <!-- Title and Item ID -->
    <h3 class="title">Edit Item</h3>
    <p class="sub-title">Editing {{item.title}} (ID: {{itemId}})</p>
    <!-- If no elements added to form, show info message -->
    <p class="warning-note" v-if="formData.length === 0">
      No data configured yet. Click an attribute in the list below to add the field to the form.
    </p>
    <!-- For each data attribute, render the correct type of input field -->
    <div class="row" v-for="(row, index) in formData" :key="row.name">
      <!-- Text box, for text/ number/ raw input elements -->
      <template v-if="row.type === 'text' || row.type === 'number'">
        <div :class="row.name === 'description' ? 'input-with-btn' : ''">
          <Input
            v-model="formData[index].value"
            :description="row.description"
            :label="row.title || row.name"
            :type="row.type"
            layout="horizontal"
          />
          <button
            v-if="row.name === 'description'"
            @click="autoFillDescription"
            class="auto-fill-btn"
            title="自动填充描述"
          >
            🤖
          </button>
        </div>
      </template>
      <!-- Radio button, used for True or False input -->
      <Radio
        v-else-if="row.type === 'boolean'"
        v-model="formData[index].value"
        :description="row.description"
        :label="row.title || row.name"
        :options="[ ...boolRadioOptions ]"
        :initialOption="boolToStr(formData[index].value)"
      />
      <!-- Select/ dropdown for enum multiple-choice input -->
      <Select
        v-else-if="row.type === 'select'"
        v-model="formData[index].value"
        :options="formData[index].enum"
        :description="row.description"
        :initialOption="formData[index].value"
        :label="row.title || row.name"
        class="edit-item-select"
      />
      <!-- Warning note, for any other data types, that aren't yet supported -->
      <div v-else>
        {{ row.name }} cannot currently be edited through the UI.
      </div>
      <BinIcon @click="() => removeField(row.name)" />
    </div>
    <!-- Show Add chips, for adding more data elements to the form -->
    <div class="add-more-inputs" v-if="additionalFormData.length > 0">
      <h4>More Fields</h4>
      <div class="more-fields">
        <span
          v-for="row in additionalFormData"
          :key="row.name"
          @click="() => appendNewField(row.name)"
          class="add-field-tag">
          <AddIcon /> {{ row.title || row.name }}
        </span>
      </div>
    </div>
    <!-- Save to state button -->
    <SaveCancelButtons :saveClick="saveItem" :cancelClick="modalClosed" />
    </div>
    <AccessError v-else />
  </modal>
</template>

<script>
import AddIcon from '@/assets/interface-icons/interactive-editor-add.svg';
import BinIcon from '@/assets/interface-icons/interactive-editor-remove.svg';
import SaveCancelButtons from '@/components/InteractiveEditor/SaveCancelButtons';
import AccessError from '@/components/Configuration/AccessError';
import Input from '@/components/FormElements/Input';
import Radio from '@/components/FormElements/Radio';
import Select from '@/components/FormElements/Select';
import StoreKeys from '@/utils/StoreMutations';
import DashySchema from '@/utils/ConfigSchema';
import { modalNames } from '@/utils/defaults';
import DescriptionGenerator from '@/utils/descriptionGenerator';

export default {
  name: 'EditItem',
  data() {
    return {
      modalName: modalNames.EDIT_ITEM,
      schema: DashySchema.properties.sections.items.properties.items.items.properties,
      formData: [], // Array of form fields
      additionalFormData: [], // Array of not-yet-used form fields
      item: {},
      boolRadioOptions: [
        { label: 'true', value: 'true' },
        { label: 'false', value: 'false' },
      ],
    };
  },
  props: {
    itemId: String,
    isNew: Boolean,
    parentSectionTitle: String, // If adding new item, which section to add it under
  },
  computed: {
    allowViewConfig() {
      return this.$store.getters.permissions.allowViewConfig;
    },
  },
  components: {
    Input,
    Radio,
    Select,
    AddIcon,
    BinIcon,
    AccessError,
    SaveCancelButtons,
  },
  mounted() {
    if (!this.isNew) { // Get existing item data
      this.item = this.getItemFromState(this.itemId);
    }
    this.formData = this.makeInitialFormData();
    this.$modal.show(modalNames.EDIT_ITEM);
  },
  methods: {
    /* For a given item ID, return the item obj from store */
    getItemFromState(id) {
      return this.$store.getters.getItemById(id);
    },
    /* Using the schema, make data structure for the UI form fields to use */
    makeRowData(property) {
      return {
        name: property,
        description: this.schema[property].description,
        value: this.item[property],
        type: this.getInputType(this.schema[property]),
        enum: this.schema[property].enum,
        title: this.schema[property].title,
      };
    },
    /* Make formatted data structure to be rendered as form elements */
    makeInitialFormData() {
      const formData = [];
      const requiredFields = ['title', 'description', 'url', 'target'];
      const unneededFields = ['id'];
      const isPrimaryField = (property) => (
        this.item[property] || requiredFields.includes(property)
      ) && !unneededFields.includes(property);
      Object.keys(this.schema).forEach((property) => {
        const singleRow = this.makeRowData(property);
        if (isPrimaryField(property)) {
          formData.push(singleRow);
        } else {
          this.additionalFormData.push(singleRow);
        }
      });
      return formData;
    },
    /* Convert boolean to string */
    boolToStr(bool) {
      if (bool) return 'true';
      if (bool === false) return 'false';
      return undefined;
    },
    /* Adds field from extras list to main form, then removes from extras list */
    appendNewField(fieldId) {
      Object.keys(this.schema).forEach((property) => {
        if (property === fieldId) {
          this.formData.push(this.makeRowData(property));
        }
      });
      this.additionalFormData.forEach((elem, index) => {
        if (elem.name === fieldId) {
          this.additionalFormData.splice(index, 1);
        }
      });
    },
    /* On Remove Field click, removes field from main form, and adds to chip list */
    removeField(fieldId) {
      this.formData.forEach((elem, index) => {
        if (elem.name === fieldId) {
          this.formData.splice(index, 1);
          this.additionalFormData.push(elem);
        }
      });
    },
    /* Use schema to determine type of form element to render, for a given attribute */
    getInputType(schemaItem) {
      const definedType = schemaItem.type;
      if (definedType === 'text') {
        return 'text';
      } else if (definedType === 'number') {
        return 'number';
      } else if (definedType === 'boolean') {
        return 'boolean';
      } else if (schemaItem.enum) {
        return 'select';
      }
      return 'text';
    },
    /* Saves the updated item to VueX Store */
    saveItem() {
      // Convert form data back into section.item data structure
      const structured = {};
      this.formData.forEach((row) => { structured[row.name] = row.value; });
      if (!structured.title) { // Missing title, show error and don't proceed
        this.$toasted.show(
          this.$t('interactive-editor.edit-item.missing-title-err'),
          { className: 'toast-error' },
        );
      } else {
        // Some attributes need a little extra formatting
        const newItem = this.formatBeforeSave(structured);
        if (this.isNew) { // Insert new item into data store
          newItem.id = `temp_${newItem.title}`;
          const payload = { newItem, targetSection: this.parentSectionTitle };
          this.$store.commit(StoreKeys.INSERT_ITEM, payload);
        } else { // Update existing item from form data, in the store
          this.$store.commit(StoreKeys.UPDATE_ITEM, { newItem, itemId: this.itemId });
        }
        // If we're not already in edit mode, enable it now
        this.$store.commit(StoreKeys.SET_EDIT_MODE, true);
        // Close edit menu
        this.$emit('closeEditMenu');
      }
    },
    /* Some fields require a bit of extra processing before they're saved */
    formatBeforeSave(item) {
      const newItem = item;
      newItem.id = this.itemId;
      // START: Auto-prepend https://
      if (newItem.url && !newItem.url.startsWith('http')) {
        newItem.url = `https://${newItem.url}`;
      }
      // END: Auto-prepend https://
      if (newItem.hotkey) newItem.hotkey = parseInt(newItem.hotkey, 10);
      const strToTags = (tags) => {
        const tagArr = (typeof tags === 'string') ? tags.split(',') : tags;
        return tagArr.map((tag) => tag.trim().toLowerCase().replace(/[^a-z0-9]+/, ''));
      };
      const strToBool = (str) => {
        if (str === undefined) return undefined;
        return str === 'true';
      };
      if (newItem.tags) newItem.tags = strToTags(newItem.tags);
      if (newItem.statusCheck) newItem.statusCheck = strToBool(newItem.statusCheck);
      if (newItem.statusCheckAllowInsecure) {
        newItem.statusCheckAllowInsecure = strToBool(newItem.statusCheckAllowInsecure);
      }
      // if (newItem.hotkey) newItem.hotkey = parseInt(newItem.hotkey, 10);
      return newItem;
    },
    /* Auto-fill description from URL */
    autoFillDescription() {
      const urlField = this.formData.find(f => f.name === 'url');
      const titleField = this.formData.find(f => f.name === 'title');
      const descField = this.formData.find(f => f.name === 'description');

      if (!urlField || !urlField.value) {
        this.$toasted.show('请先输入网址', { className: 'toast-warning' });
        return;
      }

      try {
        const result = DescriptionGenerator.generateDescription(
          urlField.value,
          titleField?.value || '',
        );

        if (descField) {
          descField.value = result.description;
        }

        const sourceText = {
          database: '数据库匹配',
          keyword: '关键词推断',
          fallback: '使用默认值',
        }[result.source] || '自动生成';

        this.$toasted.show(`✅ 已自动填充（${sourceText}）`, { className: 'toast-success' });
      } catch (error) {
        this.$toasted.show('自动填充失败', { className: 'toast-error' });
      }
    },
    /* Clean up work, triggered when modal closed */
    modalClosed() {
      this.$store.commit(StoreKeys.SET_MODAL_OPEN, false);
      this.$emit('closeEditMenu');
    },
  },
};
</script>

<style lang="scss">
@import '@/styles/style-helpers.scss';
@import '@/styles/media-queries.scss';

.edit-item-inner {
  padding: 1rem;
  background: var(--interactive-editor-background);
  color: var(--interactive-editor-color);
  height: 100%;
  overflow-y: auto;
  @extend .svg-button;
  h3.title {
    font-size: 1.5rem;
    margin: 0.25rem 0;
  }
  p.sub-title {
    margin: 0.25rem 0;
    font-size: 0.8rem;
    font-style: italic;
    opacity: var(--dimming-factor);
  }
  p.warning-note {
    color: var(--warning);
  }
  .row {
    display: flex;
    align-items: center;
    padding: 0.5rem 0;
    &:not(:last-child) {
      border-bottom: 1px dotted var(--interactive-editor-color);
    }

    // 让输入容器占据剩余空间，但不挤压其他元素
    .input-container, .select-container, .radio-container {
      flex: 1;
      min-width: 0;
      margin-right: 1rem; // 给删除按钮留空间

      // 确保horizontal布局下的input-container使用一致的label宽度
      &.horizontal {
        label.input-label {
          min-width: 100px;
          flex-basis: 100px;
          flex-grow: 0;
          flex-shrink: 0;
        }

        input.input-field {
          flex-grow: 1;
          flex-basis: 0;
        }

        p.input-description {
          flex-grow: 0;
          flex-basis: auto;
          white-space: nowrap;
        }
      }

      input.input-field {
        font-size: 1rem;
        padding: 0.35rem 0.5rem;
      }
    }

    // Select组件特殊处理，确保label宽度一致
    .select-container {
      label.select-label {
        min-width: 100px;
        flex-basis: 100px;
        flex-grow: 0;
        flex-shrink: 0;
      }

      .form-dropdown {
        flex-grow: 1;
        flex-basis: 0;
      }

      p.select-description {
        flex-grow: 0;
        flex-basis: auto;
        white-space: nowrap;
      }
    }

    // 特殊处理带自动填充按钮的描述字段
    .input-with-btn {
      flex: 1;
      display: flex;
      align-items: center;
      gap: 0.5rem;
      margin-right: 1rem;

      .input-container {
        flex: 1;
        margin-right: 0;
      }
    }

    // 删除按钮固定在最右侧，保持一致的尺寸和间距
    > svg {
      flex-shrink: 0;
      width: 1.5rem;
      height: 1.5rem;
      margin-left: auto;
    }
  }
  .more-fields {
    display: flex;
    flex-wrap: wrap;
    span.add-field-tag {
      margin: 0.2rem;
      padding: 0.2rem 0.5rem;;
      min-width: 2rem;
      display: flex;
      align-items: center;
      cursor: pointer;
      text-align: center;
      border: 1px solid var(--interactive-editor-color);
      border-radius: var(--curve-factor);
      &:hover {
        background: var(--interactive-editor-color);
        color: var(--interactive-editor-background);
        svg {
          background: var(--interactive-editor-color);
          path { fill: var(--interactive-editor-background); }
        }
      }
      svg {
        margin-right: 0.25rem;
        border: none;
      }
    }
  }

  /* Auto-fill button styles */
  .input-with-btn {
    display: flex;
    align-items: flex-end;
    gap: 0.5rem;
    width: 100%;

    .input-container {
      flex: 1;
    }

    .auto-fill-btn {
      padding: 0.5rem 1rem;
      background: var(--interactive-editor-color);
      color: var(--interactive-editor-background);
      border: 1px solid var(--interactive-editor-color);
      border-radius: var(--curve-factor);
      cursor: pointer;
      font-size: 1.2rem;
      transition: all 0.2s ease;
      height: 2.5rem;
      min-width: 3rem;

      &:hover {
        background: var(--interactive-editor-background);
        color: var(--interactive-editor-color);
        transform: scale(1.05);
      }

      &:active {
        transform: scale(0.95);
      }
    }
  }

  /* Override form element colors, with local CSS variables */
  div.input-container input.input-field,
  .radio-container div.radio-wrapper,
  .form-dropdown div.vs__dropdown-toggle {
    color: var(--interactive-editor-color);
    border-color: var(--interactive-editor-color);
    background: var(--interactive-editor-background);
  }
  svg {
    path { fill: var(--interactive-editor-color); }
    background: var(--interactive-editor-background);
    &:hover, &.selected {
      path { fill: var(--interactive-editor-background); }
      background: var(--interactive-editor-color);
    }
  }
  .edit-item-select .v-select {
    input.vs__search { color: var(--interactive-editor-color); }
    div.vs__dropdown-toggle {
      border-color: var(--interactive-editor-color);
      background: var(--interactive-editor-background);
      span.vs__selected { color: var(--interactive-editor-color); }
      .vs__actions svg {
        background: var(--interactive-editor-background);
        path { fill: var(--interactive-editor-color); }
        &:hover {
          background: var(--interactive-editor-color);
          path { fill: var(--interactive-editor-background); }
        }
      }
    }
  }
}
</style>
