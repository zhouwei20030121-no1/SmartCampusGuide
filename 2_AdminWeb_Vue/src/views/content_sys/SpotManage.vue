<template>
  <div class="page">
    <div class="page-header">
      <h2>景点管理</h2>
      <el-button type="primary" :icon="Plus">新增景点</el-button>
    </div>
    <el-card>
      <el-table :data="[]" stripe empty-text="暂无景点数据，请先对接后端接口">
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="name" label="景点名称" />
        <el-table-column prop="category" label="分类" width="100" />
        <el-table-column prop="location" label="坐标" width="200" />
        <el-table-column prop="status" label="状态" width="100" />
        <el-table-column label="操作" width="200">
          <template #default>
            <el-button type="primary" link size="small">编辑</el-button>
            <el-button type="success" link size="small">预览</el-button>
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
