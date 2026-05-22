<template>
  <div class="page">
    <h2>用户管理</h2>
    <el-card>
      <el-table :data="[]" stripe empty-text="暂无用户数据，请先对接后端接口">
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="username" label="用户名" />
        <el-table-column prop="phone" label="手机号" width="140" />
        <el-table-column prop="role" label="角色" width="100" />
        <el-table-column prop="createTime" label="注册时间" width="180" />
        <el-table-column label="操作" width="160">
          <template #default>
            <el-button type="primary" link size="small">编辑</el-button>
            <el-button type="danger" link size="small">禁用</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
</script>
