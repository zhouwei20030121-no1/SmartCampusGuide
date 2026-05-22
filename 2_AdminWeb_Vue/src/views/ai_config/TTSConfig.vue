<template>
  <div class="page">
    <h2>TTS 语音配置</h2>
    <el-card>
      <el-form label-width="120px" style="max-width:600px">
        <el-form-item label="语音引擎">
          <el-select model-value="aliyun" disabled>
            <el-option label="阿里云 TTS" value="aliyun" />
            <el-option label="百度 TTS" value="baidu" />
          </el-select>
        </el-form-item>
        <el-form-item label="默认语速">
          <el-slider :model-value="50" show-input style="width:200px" />
        </el-form-item>
        <el-form-item label="默认音量">
          <el-slider :model-value="80" show-input style="width:200px" />
        </el-form-item>
        <el-form-item label="触发距离(米)">
          <el-input-number :model-value="30" :min="5" :max="100" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary">保存配置</el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script setup lang="ts">
</script>
