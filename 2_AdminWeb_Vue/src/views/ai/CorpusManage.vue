<template>
  <div class="page-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>AI 语料库管理</span>
          <div class="header-actions">
            <el-input v-model="searchKey" placeholder="搜索语料..." style="width: 200px" clearable
              @keyup.enter="handleSearch" />
            <el-button type="primary" @click="showDialog = true">新增语料</el-button>
          </div>
        </div>
      </template>
      <el-table :data="tableData" border stripe v-loading="loading">
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column prop="question" label="问题" min-width="180" show-overflow-tooltip />
        <el-table-column prop="answer" label="回答" min-width="220" show-overflow-tooltip />
        <el-table-column prop="category" label="分类" width="100" />
        <el-table-column prop="keywords" label="关键词" width="120" />
        <el-table-column prop="enabled" label="状态" width="80">
          <template #default="{ row }">
            <el-tag :type="row.enabled ? 'success' : 'info'" size="small">
              {{ row.enabled ? '启用' : '停用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150">
          <template #default="{ row }">
            <el-button size="small" type="primary" link @click="handleEdit(row)">编辑</el-button>
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

    <el-dialog v-model="showDialog" title="新增语料" width="600px">
      <el-form :model="form" label-width="80px">
        <el-form-item label="关联景点">
          <el-select v-model="form.spotId" placeholder="选择景点（可选）" style="width: 100%" clearable>
            <el-option v-for="s in spotOptions" :key="s.id" :label="s.name" :value="s.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="问题">
          <el-input v-model="form.question" placeholder="用户可能问的问题" />
        </el-form-item>
        <el-form-item label="回答">
          <el-input v-model="form.answer" type="textarea" :rows="4" placeholder="AI 的回答内容" />
        </el-form-item>
        <el-form-item label="分类">
          <el-input v-model="form.category" placeholder="如：校园历史、建筑介绍、生活服务" />
        </el-form-item>
        <el-form-item label="关键词">
          <el-input v-model="form.keywords" placeholder="逗号分隔的关键词，用于检索匹配" />
        </el-form-item>
        <el-form-item label="启用">
          <el-switch v-model="form.enabled" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showDialog = false">取消</el-button>
        <el-button type="primary" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import request from '@/api/request'

const loading = ref(false)
const tableData = ref([])
const searchKey = ref('')
const showDialog = ref(false)
const page = ref(1)
const total = ref(0)

const spotOptions = ref<any[]>([])

const form = reactive({
  spotId: null as number | null,
  question: '',
  answer: '',
  category: '',
  keywords: '',
  enabled: true,
})

const fetchCorpus = async () => {
  loading.value = true
  try {
    const data = await request.get('/ai/corpus/list', { params: { page: page.value, size: 10 } })
    tableData.value = (data as any).records || []
    total.value = (data as any).total || 0
  } finally {
    loading.value = false
  }
}

const handleSearch = async () => {
  if (!searchKey.value) {
    fetchCorpus()
    return
  }
  loading.value = true
  try {
    const data = await request.get('/ai/corpus/search', { params: { keyword: searchKey.value } })
    tableData.value = (data as any) || []
    total.value = tableData.value.length
  } finally {
    loading.value = false
  }
}

const handleEdit = (row: any) => {
  Object.assign(form, row)
  showDialog.value = true
}

const handleSave = async () => {
  try {
    await request.post('/ai/corpus', form)
    ElMessage.success('保存成功')
    showDialog.value = false
    fetchCorpus()
  } catch {
    ElMessage.error('保存失败')
  }
}

onMounted(fetchCorpus)
</script>

<style scoped>
.page-container { padding: 0; }
.card-header { display: flex; justify-content: space-between; align-items: center; }
.header-actions { display: flex; gap: 12px; }
.pagination-wrap { margin-top: 16px; display: flex; justify-content: flex-end; }
</style>
