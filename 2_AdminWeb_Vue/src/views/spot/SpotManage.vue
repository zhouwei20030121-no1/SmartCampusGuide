<template>
  <div class="page-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>景点管理</span>
          <div class="header-actions">
            <el-input v-model="searchKey" placeholder="搜索景点..." style="width: 200px" clearable />
            <el-button type="primary">新增景点</el-button>
          </div>
        </div>
      </template>
      <el-table :data="tableData" border stripe v-loading="loading">
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column prop="name" label="景点名称" />
        <el-table-column prop="category" label="分类" />
        <el-table-column prop="visitCount" label="访问量" />
        <el-table-column prop="rating" label="评分" />
        <el-table-column label="操作" width="200">
          <template #default="{ row }">
            <el-button size="small" type="primary" link @click="handleEdit(row)">编辑</el-button>
            <el-button size="small" type="warning" link>内容</el-button>
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
const searchKey = ref('')
const page = ref(1)
const total = ref(0)

const fetchSpots = async () => {
  loading.value = true
  try {
    const data = await request.get('/spot/list', { params: { page: page.value, size: 10 } })
    tableData.value = (data as any).records || []
    total.value = (data as any).total || 0
  } finally {
    loading.value = false
  }
}

const handleEdit = (row: any) => {
  console.log('编辑景点:', row)
}

onMounted(fetchSpots)
</script>

<style scoped>
.page-container { padding: 0; }
.card-header { display: flex; justify-content: space-between; align-items: center; }
.header-actions { display: flex; gap: 12px; }
.pagination-wrap { margin-top: 16px; display: flex; justify-content: flex-end; }
</style>
