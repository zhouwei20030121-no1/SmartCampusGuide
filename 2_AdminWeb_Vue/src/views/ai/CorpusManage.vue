<template>
  <div class="page-container">
    <!-- 页面标题 -->
    <div class="page-header">
      <div>
        <h2>AI 语料库管理</h2>
        <p>管理AI智能问答的语料素材，提升回答准确度</p>
      </div>
      <el-button type="primary" @click="handleAdd">
        <el-icon><Plus /></el-icon>
        新增语料
      </el-button>
    </div>

    <!-- 统计卡片 -->
    <el-row :gutter="20">
      <el-col :span="8">
        <el-card class="stat-card" shadow="hover">
          <div class="stat-content">
            <div class="stat-icon" style="background: #e6f7ff;">
              <el-icon :size="24" color="#1890ff"><Collection /></el-icon>
            </div>
            <div class="stat-info">
              <div class="stat-label">已启用</div>
              <div class="stat-value">{{ stats.enabled }}</div>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card class="stat-card" shadow="hover">
          <div class="stat-content">
            <div class="stat-icon" style="background: #fff7e6;">
              <el-icon :size="24" color="#fa8c16"><Remove /></el-icon>
            </div>
            <div class="stat-info">
              <div class="stat-label">已停用</div>
              <div class="stat-value">{{ stats.disabled }}</div>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card class="stat-card" shadow="hover">
          <div class="stat-content">
            <div class="stat-icon" style="background: #f0f5ff;">
              <el-icon :size="24" color="#722ed1"><Files /></el-icon>
            </div>
            <div class="stat-info">
              <div class="stat-label">分类数</div>
              <div class="stat-value">{{ stats.categories }}</div>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 表格区域 -->
    <el-card class="table-card">
      <!-- 搜索栏 -->
      <div class="toolbar">
        <div class="toolbar-left">
          <el-select
            v-model="filterCategory"
            placeholder="选择分类"
            clearable
            style="width: 160px"
            @change="handleFilterChange"
          >
            <el-option
              v-for="cat in categoryList"
              :key="cat"
              :label="cat"
              :value="cat"
            />
          </el-select>
          <el-select
            v-model="filterStatus"
            placeholder="选择状态"
            clearable
            style="width: 120px; margin-left: 10px"
            @change="handleFilterChange"
          >
            <el-option label="启用" :value="1" />
            <el-option label="停用" :value="0" />
          </el-select>
        </div>
        <div class="toolbar-right">
          <el-input
            v-model="searchKey"
            placeholder="搜索问题或关键词..."
            clearable
            class="search-input"
            @keyup.enter="handleSearch"
          />
          <el-button type="primary" @click="handleSearch">
            <el-icon><Search /></el-icon>
            搜索
          </el-button>
          <el-button @click="handleReset">
            <el-icon><Refresh /></el-icon>
            重置
          </el-button>
        </div>
      </div>

      <!-- 表格 -->
      <el-table
        :data="tableData"
        border
        stripe
        v-loading="loading"
        class="corpus-table"
        empty-text="暂无语料数据"
      >
        <el-table-column prop="id" label="ID" width="70" />

        <el-table-column label="问题" min-width="180" show-overflow-tooltip>
          <template #default="{ row }">
            <span class="question-text">{{ row.title }}</span>
          </template>
        </el-table-column>

        <el-table-column label="回答" min-width="220" show-overflow-tooltip>
          <template #default="{ row }">
            <span class="answer-text">{{ row.content }}</span>
          </template>
        </el-table-column>

        <el-table-column label="分类" width="120">
          <template #default="{ row }">
            <el-tag :type="getCategoryType(row.category)" effect="plain" size="small">
              {{ row.category || '未分类' }}
            </el-tag>
          </template>
        </el-table-column>

        <el-table-column label="关键词" width="150">
          <template #default="{ row }">
            <div class="keyword-tags">
              <el-tag
                v-for="(kw, index) in getKeywords(row.keywords)"
                :key="index"
                size="small"
                class="keyword-tag"
              >
                {{ kw }}
              </el-tag>
              <span v-if="!row.keywords" class="empty-text">-</span>
            </div>
          </template>
        </el-table-column>

        <el-table-column label="关联景点" width="120">
          <template #default="{ row }">
            <span v-if="row.spotName">{{ row.spotName }}</span>
            <span v-else class="empty-text">通用</span>
          </template>
        </el-table-column>

        <el-table-column label="状态" width="80" align="center">
          <template #default="{ row }">
            <el-switch
              :model-value="row.status === 1"
              @change="(val: boolean) => handleStatusChange(row, val)"
              size="small"
              style="--el-switch-on-color: #13ce66; --el-switch-off-color: #ff4949;"
            />
          </template>
        </el-table-column>

        <el-table-column label="更新时间" width="170">
          <template #default="{ row }">
            <span class="time-text">{{ formatDateTime(row.updateTime) }}</span>
          </template>
        </el-table-column>

        <el-table-column label="操作" width="160" fixed="right">
          <template #default="{ row }">
            <el-button size="small" type="primary" link @click="handleEdit(row)">
              <el-icon><Edit /></el-icon>
              编辑
            </el-button>
            <el-button size="small" type="danger" link @click="handleDelete(row)">
              <el-icon><Delete /></el-icon>
              删除
            </el-button>
          </template>
        </el-table-column>
      </el-table>

      <!-- 分页 -->
      <div class="pagination-wrap">
        <el-pagination
          v-model:current-page="page"
          v-model:page-size="pageSize"
          :page-sizes="[5, 10, 20, 50]"
          :total="total"
          layout="total, sizes, prev, pager, next, jumper"
          @size-change="handleSizeChange"
          @current-change="handlePageChange"
        />
      </div>
    </el-card>

    <!-- 新增/编辑语料弹窗 -->
    <el-dialog
      v-model="dialogVisible"
      :title="dialogTitle"
      width="650px"
      :close-on-click-modal="false"
      @close="handleDialogClose"
    >
      <el-form
        ref="formRef"
        :model="formData"
        :rules="formRules"
        label-width="100px"
        class="corpus-form"
      >
        <div class="section-title">基本信息</div>

        <el-form-item label="关联景点" prop="spotId">
          <el-select
            v-model="formData.spotId"
            placeholder="选择关联景点（可选）"
            style="width: 100%"
            clearable
            filterable
          >
            <el-option
              v-for="s in spotOptions"
              :key="s.id"
              :label="s.name"
              :value="s.id"
            />
          </el-select>
        </el-form-item>

        <el-form-item label="分类" prop="category">
          <el-select
            v-model="formData.category"
            placeholder="请选择或输入分类"
            style="width: 100%"
            filterable
            allow-create
          >
            <el-option
              v-for="cat in categoryList"
              :key="cat"
              :label="cat"
              :value="cat"
            />
          </el-select>
        </el-form-item>

        <el-form-item label="状态" prop="status">
          <el-radio-group v-model="formData.status">
            <el-radio :label="1">启用</el-radio>
            <el-radio :label="0">停用</el-radio>
          </el-radio-group>
        </el-form-item>

        <div class="section-title">语料内容</div>

        <el-form-item label="问题" prop="title">
          <el-input
            v-model="formData.title"
            placeholder="用户可能问的问题，如：图书馆在哪里？"
            maxlength="200"
            show-word-limit
          />
        </el-form-item>

        <el-form-item label="回答" prop="content">
          <el-input
            v-model="formData.content"
            type="textarea"
            :rows="5"
            placeholder="AI的回答内容，如：中心图书馆位于校园中部..."
            maxlength="1000"
            show-word-limit
          />
        </el-form-item>

        <el-form-item label="关键词">
          <div class="keyword-input-area">
            <el-input
              v-model="keywordInput"
              placeholder="输入关键词后按回车添加"
              @keyup.enter="addKeyword"
              clearable
            >
              <template #append>
                <el-button @click="addKeyword">添加</el-button>
              </template>
            </el-input>
            <div class="keyword-list" v-if="keywordList.length > 0">
              <el-tag
                v-for="(kw, index) in keywordList"
                :key="index"
                closable
                @close="removeKeyword(index)"
                class="keyword-item"
              >
                {{ kw }}
              </el-tag>
            </div>
            <div class="form-tip">关键词用于AI检索匹配，多个关键词用逗号分隔</div>
          </div>
        </el-form-item>
      </el-form>

      <template #footer>
        <div class="dialog-footer">
          <el-button @click="dialogVisible = false">取消</el-button>
          <el-button type="primary" @click="handleSubmit" :loading="submitLoading">
            {{ isEdit ? '保存修改' : '确认新增' }}
          </el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import type { FormInstance, FormRules } from 'element-plus'
import {
  Plus,
  Search,
  Refresh,
  Edit,
  Delete,
  Collection,
  Remove,
  Files,
} from '@element-plus/icons-vue'
import request from '@/api/request'

// 加载状态
const loading = ref(false)
const submitLoading = ref(false)

// 表格数据
const tableData = ref<any[]>([])
const searchKey = ref('')
const filterCategory = ref('')
const filterStatus = ref<number | null>(null)
const page = ref(1)
const pageSize = ref(10)
const total = ref(0)

// 统计数据
const stats = reactive({
  enabled: 0,
  disabled: 0,
  categories: 0,
})

// 分类列表
const categoryList = ref<string[]>([])

// 景点选项
const spotOptions = ref<any[]>([])

// 弹窗控制
const dialogVisible = ref(false)
const formRef = ref<FormInstance>()

// 编辑模式
const isEdit = computed(() => !!formData.id)
const dialogTitle = computed(() => isEdit.value ? '编辑语料' : '新增语料')

// 关键词输入
const keywordInput = ref('')
const keywordList = ref<string[]>([])

// 表单数据
const formData = reactive({
  id: null as number | null,
  spotId: null as number | null,
  title: '',
  content: '',
  category: '',
  keywords: '',
  status: 1,
})

// 表单验证规则
const formRules: FormRules = {
  title: [
    { required: true, message: '请输入问题', trigger: 'blur' },
    { min: 2, max: 200, message: '长度在 2 到 200 个字符', trigger: 'blur' }
  ],
  content: [
    { required: true, message: '请输入回答', trigger: 'blur' },
    { min: 2, max: 1000, message: '长度在 2 到 1000 个字符', trigger: 'blur' }
  ],
  category: [
    { required: true, message: '请选择或输入分类', trigger: 'change' }
  ],
}

// 获取关键词数组
const getKeywords = (keywords: string) => {
  if (!keywords) return []
  return keywords.split(',').filter(Boolean).map(k => k.trim())
}

// 获取分类标签类型
const getCategoryType = (category: string) => {
  const typeMap: Record<string, string> = {
    '校园历史': 'warning',
    '建筑介绍': '',
    '生活服务': 'success',
    '学术资源': 'info',
    '校园文化': 'danger',
    '交通出行': '',
  }
  return typeMap[category] || 'info'
}

// 获取语料列表
const fetchCorpus = async () => {
  loading.value = true
  try {
    const params: any = {
      keyword: searchKey.value,
      page: page.value,
      size: pageSize.value,
    }
    if (filterCategory.value) params.category = filterCategory.value
    if (filterStatus.value !== null && filterStatus.value !== undefined) {
      params.status = filterStatus.value
    }

    const response = await request.get('/ai/corpus/list', { params })
    const data = response || (response as any).data
    tableData.value = data.records || []
    total.value = data.total || 0
  } catch (error) {
    console.error('获取语料列表失败:', error)
    tableData.value = []
    total.value = 0
  } finally {
    loading.value = false
  }
}

// 获取统计数据
const fetchStats = async () => {
  try {
    const response = await request.get('/ai/corpus/stats')
    const data = response || (response as any).data
    if (data) {
      stats.enabled = data.enabled || 0
      stats.disabled = data.disabled || 0
      stats.categories = data.categories || 0
    }
  } catch (error) {
    console.error('获取统计数据失败:', error)
  }
}

// 获取分类列表
const fetchCategories = async () => {
  try {
    const response = await request.get('/ai/corpus/categories')
    const data = response || (response as any).data
    categoryList.value = data || []
  } catch (error) {
    console.error('获取分类列表失败:', error)
  }
}

// 获取景点列表
const fetchSpots = async () => {
  try {
    const response = await request.get('/spot/list', {
      params: { page: 1, size: 200 }
    })
    const data = response || (response as any).data
    spotOptions.value = data.records || []
  } catch (error) {
    console.error('获取景点列表失败:', error)
  }
}

// 搜索
const handleSearch = () => {
  page.value = 1
  fetchCorpus()
}

// 重置
const handleReset = () => {
  searchKey.value = ''
  filterCategory.value = ''
  filterStatus.value = null
  page.value = 1
  fetchCorpus()
}

// 筛选变化
const handleFilterChange = () => {
  page.value = 1
  fetchCorpus()
}

// 分页
const handlePageChange = (newPage: number) => {
  page.value = newPage
  fetchCorpus()
}

const handleSizeChange = (newSize: number) => {
  pageSize.value = newSize
  page.value = 1
  fetchCorpus()
}

// 新增
const handleAdd = () => {
  resetFormData()
  dialogVisible.value = true
}

// 编辑
const handleEdit = (row: any) => {
  fillFormData(row)
  dialogVisible.value = true
}

// 填充表单
const fillFormData = (row: any) => {
  formData.id = row.id
  formData.spotId = row.spotId || null
  formData.title = row.title || ''
  formData.content = row.content || ''
  formData.category = row.category || ''
  formData.keywords = row.keywords || ''
  formData.status = row.status !== undefined ? row.status : 1

  keywordList.value = getKeywords(row.keywords || '')
  keywordInput.value = ''
}

// 添加关键词
const addKeyword = () => {
  const kw = keywordInput.value.trim()
  if (!kw) return
  if (keywordList.value.includes(kw)) {
    ElMessage.warning('关键词已存在')
    return
  }
  keywordList.value.push(kw)
  keywordInput.value = ''
  updateKeywordsField()
}

// 移除关键词
const removeKeyword = (index: number) => {
  keywordList.value.splice(index, 1)
  updateKeywordsField()
}

// 更新关键词字段
const updateKeywordsField = () => {
  formData.keywords = keywordList.value.join(',')
}

// 删除
const handleDelete = (row: any) => {
  ElMessageBox.confirm(
    `确定要删除语料 "${row.title}" 吗？`,
    '删除确认',
    {
      confirmButtonText: '确定删除',
      cancelButtonText: '取消',
      type: 'warning',
      confirmButtonClass: 'el-button--danger',
    }
  ).then(async () => {
    try {
      await request.delete(`/ai/corpus/${row.id}`)
      ElMessage.success('删除成功')
      if (tableData.value.length === 1 && page.value > 1) page.value--
      fetchCorpus()
      fetchStats()
    } catch (error) {
      console.error('删除失败:', error)
      ElMessage.error('删除失败')
    }
  }).catch(() => {})
}

// 状态切换
const handleStatusChange = async (row: any, value: boolean) => {
  try {
    const status = value ? 1 : 0
    await request.patch(`/ai/corpus/${row.id}/status`, { status })
    row.status = status
    ElMessage.success(`已${value ? '启用' : '停用'}语料`)
    fetchStats()
  } catch (error) {
    console.error('修改状态失败:', error)
    ElMessage.error('操作失败')
    row.status = row.status === 1 ? 0 : 1
  }
}

// 提交
const handleSubmit = async () => {
  if (!formRef.value) return

  await formRef.value.validate(async (valid) => {
    if (valid) {
      submitLoading.value = true
      try {
        updateKeywordsField()
        const submitData = {
          spotId: formData.spotId,
          title: formData.title,
          content: formData.content,
          category: formData.category,
          keywords: formData.keywords,
          status: formData.status,
        }

        if (isEdit.value) {
          await request.put(`/ai/corpus/${formData.id}`, submitData)
          ElMessage.success('语料更新成功')
        } else {
          await request.post('/ai/corpus', submitData)
          ElMessage.success('语料创建成功')
        }
        dialogVisible.value = false
        fetchCorpus()
        fetchStats()
        fetchCategories()
      } catch (error) {
        console.error('提交失败:', error)
        ElMessage.error('操作失败')
      } finally {
        submitLoading.value = false
      }
    }
  })
}

// 关闭弹窗
const handleDialogClose = () => {
  if (formRef.value) formRef.value.resetFields()
}

// 重置表单
const resetFormData = () => {
  formData.id = null
  formData.spotId = null
  formData.title = ''
  formData.content = ''
  formData.category = ''
  formData.keywords = ''
  formData.status = 1
  keywordList.value = []
  keywordInput.value = ''
  if (formRef.value) formRef.value.resetFields()
}

// 格式化日期
const formatDateTime = (dateTime: string | null) => {
  if (!dateTime) return '-'
  try {
    const date = new Date(dateTime)
    if (isNaN(date.getTime())) return '-'
    return date.toLocaleString('zh-CN', {
      year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit',
      hour12: false
    })
  } catch { return '-' }
}

onMounted(() => {
  fetchCorpus()
  fetchStats()
  fetchCategories()
  fetchSpots()
})
</script>

<style scoped>
.page-container {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.page-header h2 {
  font-size: 28px;
  color: #1A5276;
  margin-bottom: 6px;
}

.page-header p {
  color: #64748b;
  font-size: 14px;
}

/* 统计卡片 */
.stat-card {
  border-radius: 16px;
  cursor: default;
}

.stat-content {
  display: flex;
  align-items: center;
  gap: 16px;
}

.stat-icon {
  width: 48px;
  height: 48px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.stat-info {
  flex: 1;
}

.stat-label {
  font-size: 13px;
  color: #999;
  margin-bottom: 4px;
}

.stat-value {
  font-size: 28px;
  font-weight: 700;
  color: #333;
}

/* 表格 */
.table-card {
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.55);
  backdrop-filter: blur(14px);
  border: 1px solid rgba(255, 255, 255, 0.45);
}

.toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  flex-wrap: wrap;
  gap: 12px;
}

.toolbar-left {
  display: flex;
  align-items: center;
}

.toolbar-right {
  display: flex;
  gap: 10px;
  align-items: center;
}

.search-input {
  width: 220px;
}

.question-text {
  font-weight: 500;
  color: #333;
}

.answer-text {
  color: #666;
  font-size: 13px;
}

.keyword-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.keyword-tag {
  margin: 1px 0;
}

.empty-text {
  color: #c0c4cc;
}

.time-text {
  font-size: 13px;
  color: #666;
}

.pagination-wrap {
  margin-top: 20px;
  display: flex;
  justify-content: flex-end;
}

/* 表单样式 */
.corpus-form {
  max-height: 500px;
  overflow-y: auto;
  padding-right: 10px;
}

.section-title {
  font-size: 15px;
  font-weight: 600;
  color: #1A5276;
  margin: 20px 0 14px 0;
  padding-bottom: 6px;
  border-bottom: 2px solid rgba(26, 82, 118, 0.15);
}

.section-title:first-child {
  margin-top: 0;
}

.keyword-input-area {
  width: 100%;
}

.keyword-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 10px;
}

.keyword-item {
  font-size: 13px;
}

.form-tip {
  font-size: 12px;
  color: #999;
  margin-top: 5px;
}

.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

:deep(.el-table__row .el-button + .el-button) {
  margin-left: 4px;
}
</style>
