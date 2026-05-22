<template>
  <div class="page-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>用户管理</span>
          <el-button type="primary" size="small">新增用户</el-button>
        </div>
      </template>
      <el-table :data="tableData" border stripe v-loading="loading">
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="username" label="用户名" />
        <el-table-column prop="studentId" label="学号" />
        <el-table-column prop="phone" label="手机号" />
        <el-table-column prop="role" label="角色" />
        <el-table-column prop="createTime" label="注册时间" />
        <el-table-column label="操作" width="180">
          <template #default>
            <el-button size="small" type="primary" link>编辑</el-button>
            <el-button size="small" type="danger" link>删除</el-button>
          </template>
        </el-table-column>
      </el-table>
      <div class="pagination-wrap">
        <el-pagination
          v-model:current-page="page"
          :page-size="10"
          :total="total"
          layout="total, prev, pager, next"
        />
      </div>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import request from '@/api/request'

const loading = ref(false)
const tableData = ref([])
const page = ref(1)
const total = ref(0)

const fetchUsers = async () => {
  loading.value = true
  try {
    const data = await request.get('/user/list', { params: { page: page.value, size: 10 } })
    tableData.value = (data as any).records || []
    total.value = (data as any).total || 0
  } finally {
    loading.value = false
  }
}

onMounted(fetchUsers)
</script>

<style scoped>
.page-container { padding: 0; }
.card-header { display: flex; justify-content: space-between; align-items: center; }
.pagination-wrap { margin-top: 16px; display: flex; justify-content: flex-end; }
</style>
