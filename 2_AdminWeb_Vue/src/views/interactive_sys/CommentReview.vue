<template>
  <div class="page">
    <h2>评论审核</h2>
    <el-card>
      <el-tabs model-value="pending">
        <el-tab-pane label="待审核" name="pending" />
        <el-tab-pane label="已通过" name="approved" />
        <el-tab-pane label="已驳回" name="rejected" />
      </el-tabs>
      <el-table :data="[]" stripe empty-text="暂无待审核评论">
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="content" label="评论内容" />
        <el-table-column prop="user" label="用户" width="120" />
        <el-table-column prop="spot" label="所属景点" width="140" />
        <el-table-column prop="time" label="时间" width="180" />
        <el-table-column label="操作" width="160">
          <template #default>
            <el-button type="success" size="small">通过</el-button>
            <el-button type="danger" size="small">驳回</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
</script>
