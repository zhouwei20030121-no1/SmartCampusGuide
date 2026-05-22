<template>
  <div class="page">
    <div class="page-header">
      <h2>语料库管理</h2>
      <el-button type="primary" :icon="Plus">新增语料</el-button>
    </div>
    <el-card>
      <el-table :data="[]" stripe empty-text="暂无语料数据，请先对接后端接口">
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="question" label="意图/问题" />
        <el-table-column prop="answer" label="回答/文案" />
        <el-table-column prop="scene" label="适用场景" width="120" />
        <el-table-column label="操作" width="160">
          <template #default>
            <el-button type="primary" link size="small">编辑</el-button>
            <el-button type="danger" link size="small">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { Plus } from '@element-plus/icons-vue'
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
</style>
