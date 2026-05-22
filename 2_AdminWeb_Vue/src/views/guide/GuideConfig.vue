<template>
  <div class="page-container">
    <el-card>
      <template #header>
        <span>语音讲解配置</span>
      </template>
      <el-tabs v-model="activeTab">
        <el-tab-pane label="TTS 引擎配置" name="tts">
          <el-form label-width="120px">
            <el-form-item label="语音合成引擎">
              <el-select v-model="ttsConfig.engine" style="width: 240px">
                <el-option label="阿里云语音合成" value="aliyun" />
                <el-option label="讯飞语音合成" value="iflytek" />
                <el-option label="OpenAI TTS" value="openai" />
              </el-select>
            </el-form-item>
            <el-form-item label="默认语速">
              <el-slider v-model="ttsConfig.speed" :min="50" :max="200" show-input style="width: 300px" />
            </el-form-item>
            <el-form-item label="默认音调">
              <el-slider v-model="ttsConfig.pitch" :min="50" :max="200" show-input style="width: 300px" />
            </el-form-item>
            <el-form-item label="默认音量">
              <el-slider v-model="ttsConfig.volume" :min="0" :max="100" show-input style="width: 300px" />
            </el-form-item>
            <el-form-item>
              <el-button type="primary" @click="saveTTSConfig">保存配置</el-button>
            </el-form-item>
          </el-form>
        </el-tab-pane>
        <el-tab-pane label="触发配置" name="trigger">
          <el-alert
            title="地理围栏触发配置"
            type="info"
            description="当用户进入景点周边指定半径范围时，自动触发语音讲解播放"
            show-icon
            :closable="false"
            style="margin-bottom: 16px"
          />
          <el-form label-width="120px">
            <el-form-item label="全局触发开关">
              <el-switch v-model="triggerConfig.enabled" />
            </el-form-item>
            <el-form-item label="默认触发半径">
              <el-input-number v-model="triggerConfig.defaultRadius" :min="10" :max="500" />
              <span style="margin-left: 8px; color: #999">米</span>
            </el-form-item>
            <el-form-item>
              <el-button type="primary" @click="saveTriggerConfig">保存配置</el-button>
            </el-form-item>
          </el-form>
        </el-tab-pane>
      </el-tabs>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { ElMessage } from 'element-plus'

const activeTab = ref('tts')

const ttsConfig = reactive({
  engine: 'aliyun',
  speed: 100,
  pitch: 100,
  volume: 80,
})

const triggerConfig = reactive({
  enabled: true,
  defaultRadius: 50,
})

const saveTTSConfig = () => ElMessage.success('TTS 配置已保存')
const saveTriggerConfig = () => ElMessage.success('触发配置已保存')
</script>

<style scoped>
.page-container { padding: 0; }
</style>
