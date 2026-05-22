<template>
  <div class="page-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>评论审核</span>
          <el-radio-group v-model="filter">
            <el-radio-button value="pending">待审核</el-radio-button>
            <el-radio-button value="approved">已通过</el-radio-button>
            <el-radio-button value="rejected">已驳回</el-radio-button>
          </el-radio-group>
        </div>
      </template>
      <el-table :data="tableData" border stripe v-loading="loading">
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column prop="userId" label="用户ID" width="80" />
        <el-table-column prop="spotId" label="景点ID" width="80" />
        <el-table-column prop="content" label="评论内容" min-width="200" show-overflow-tooltip />
        <el-table-column prop="rating" label="评分" width="80">
          <template #default="{ row }">
            <el-rate v-model="row.rating" disabled size="small" />
          </template>
        </el-table-column>
        <el-table-column prop="createTime" label="时间" width="160" />
        <el-table-column label="操作" width="180">
          <template #default="{ row }">
            <el-button size="small" type="success" @click="review(row.id, 'approved')">通过</el-button>
            <el-button size="small" type="danger" @click="review(row.id, 'rejected')">驳回</el-button>
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
import { ElMessage } from 'element-plus'
import request from '@/api/request'

const loading = ref(false)
const tableData = ref([])
const filter = ref('pending')
const page = ref(1)
const total = ref(0)

const fetchComments = async () => {
  loading.value = true
  try {
    const data = await request.get('/comment/pending', { params: { page: page.value, size: 10 } })
    tableData.value = (data as any).records || []
    total.value = (data as any).total || 0
  } finally {
    loading.value = false
  }
}

const review = async (id: number, status: string) => {
  try {
    await request.put(`/comment/review/${id}`, { status })
    ElMessage.success(status === 'approved' ? '已通过' : '已驳回')
    fetchComments()
  } catch {
    ElMessage.error('操作失败')
  }
}

onMounted(fetchComments)
</script>

<style scoped>
.page-container { padding: 0; }
.card-header { display: flex; justify-content: space-between; align-items: center; }
.pagination-wrap { margin-top: 16px; display: flex; justify-content: flex-end; }
</style>
