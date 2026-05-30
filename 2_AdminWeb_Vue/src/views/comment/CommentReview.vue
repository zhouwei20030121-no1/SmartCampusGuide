<template>
  <div class="page-container">
    <!-- 页面标题 -->
    <div class="page-header">
      <div>
        <h2>评论审核管理</h2>
        <p>审核用户评论内容，管理评论合规性</p>
      </div>
    </div>

    <!-- 统计卡片 -->
    <el-row :gutter="20">
      <el-col :span="8">
        <el-card class="stat-card" shadow="hover" :class="{ active: filter === '0' }" @click="filter = '0'">
          <div class="stat-content">
            <div class="stat-icon" style="background: #fff7e6;">
              <el-icon :size="24" color="#fa8c16"><Clock /></el-icon>
            </div>
            <div class="stat-info">
              <div class="stat-label">待审核</div>
              <div class="stat-value">{{ stats.pending }}</div>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card class="stat-card" shadow="hover" :class="{ active: filter === '1' }" @click="filter = '1'">
          <div class="stat-content">
            <div class="stat-icon" style="background: #f6ffed;">
              <el-icon :size="24" color="#52c41a"><CircleCheck /></el-icon>
            </div>
            <div class="stat-info">
              <div class="stat-label">已通过</div>
              <div class="stat-value">{{ stats.approved }}</div>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card class="stat-card" shadow="hover" :class="{ active: filter === '2' }" @click="filter = '2'">
          <div class="stat-content">
            <div class="stat-icon" style="background: #fff1f0;">
              <el-icon :size="24" color="#ff4d4f"><CircleClose /></el-icon>
            </div>
            <div class="stat-info">
              <div class="stat-label">已驳回</div>
              <div class="stat-value">{{ stats.rejected }}</div>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 表格区域 -->
    <el-card class="table-card">
      <!-- 搜索栏 -->
      <div class="toolbar">
        <el-radio-group v-model="filter" @change="handleFilterChange">
          <el-radio-button value="0">待审核</el-radio-button>
          <el-radio-button value="1">已通过</el-radio-button>
          <el-radio-button value="2">已驳回</el-radio-button>
        </el-radio-group>

        <div class="toolbar-right">
          <el-input
            v-model="searchKey"
            placeholder="搜索评论内容..."
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
        class="comment-table"
        empty-text="暂无评论数据"
      >
        <el-table-column prop="id" label="ID" width="70" />

        <el-table-column label="用户" width="120">
          <template #default="{ row }">
            <div class="user-info">
              <el-avatar :size="28" style="background: #1A5276; font-size: 12px;">
                {{ (row.username || '用').charAt(0) }}
              </el-avatar>
              <span class="username">{{ row.username || '用户' + row.userId }}</span>
            </div>
          </template>
        </el-table-column>

        <el-table-column label="景点" width="130">
          <template #default="{ row }">
            <el-tag type="info" effect="plain" size="small">
              {{ row.spotName || '景点' + row.spotId }}
            </el-tag>
          </template>
        </el-table-column>

        <el-table-column label="评论内容" min-width="250">
          <template #default="{ row }">
            <div class="comment-content">
              <el-tooltip :content="row.content" placement="top" :show-after="500">
                <span class="content-text">{{ row.content }}</span>
              </el-tooltip>
              <div v-if="row.rating" class="comment-rating">
                <el-rate :model-value="row.rating" disabled size="small" show-score />
              </div>
            </div>
          </template>
        </el-table-column>

        <el-table-column label="状态" width="100" align="center">
          <template #default="{ row }">
            <el-tag v-if="row.status === 0" type="warning" size="small">待审核</el-tag>
            <el-tag v-else-if="row.status === 1" type="success" size="small">已通过</el-tag>
            <el-tag v-else-if="row.status === 2" type="danger" size="small">已驳回</el-tag>
          </template>
        </el-table-column>

        <el-table-column label="评论时间" width="170">
          <template #default="{ row }">
            <span class="time-text">{{ formatDateTime(row.createTime || row.createdAt) }}</span>
          </template>
        </el-table-column>

        <el-table-column label="审核时间" width="170">
          <template #default="{ row }">
            <span class="time-text">{{ formatDateTime(row.reviewTime) }}</span>
          </template>
        </el-table-column>

        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <template v-if="row.status === 0">
              <el-button size="small" type="success" @click="handleApprove(row)">
                <el-icon><Check /></el-icon>
                通过
              </el-button>
              <el-button size="small" type="danger" @click="handleReject(row)">
                <el-icon><Close /></el-icon>
                驳回
              </el-button>
            </template>
            <template v-else-if="row.status === 2">
              <el-button size="small" type="warning" @click="handleApprove(row)">
                <el-icon><RefreshRight /></el-icon>
                改为通过
              </el-button>
            </template>
            <template v-else>
              <el-tag type="success" size="small">已通过</el-tag>
            </template>
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

    <!-- 驳回原因弹窗 -->
    <el-dialog
      v-model="rejectDialogVisible"
      title="驳回评论"
      width="500px"
      :close-on-click-modal="false"
    >
      <div class="reject-dialog">
        <p>确定要驳回该评论吗？</p>
        <div class="reject-comment-preview">
          <span class="reject-label">评论内容：</span>
          <p class="reject-content">{{ rejectingComment?.content }}</p>
        </div>
        <el-form label-width="80px">
          <el-form-item label="驳回原因">
            <el-select v-model="rejectReason" placeholder="请选择驳回原因" style="width: 100%">
              <el-option label="内容不当" value="内容不当" />
              <el-option label="广告信息" value="广告信息" />
              <el-option label="与景点无关" value="与景点无关" />
              <el-option label="重复评论" value="重复评论" />
              <el-option label="其他原因" value="其他原因" />
            </el-select>
          </el-form-item>
          <el-form-item label="备注">
            <el-input
              v-model="rejectNote"
              type="textarea"
              :rows="3"
              placeholder="可选：填写驳回备注"
            />
          </el-form-item>
        </el-form>
      </div>
      <template #footer>
        <el-button @click="rejectDialogVisible = false">取消</el-button>
        <el-button type="danger" @click="confirmReject" :loading="rejectLoading">
          确认驳回
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  Clock,
  CircleCheck,
  CircleClose,
  Search,
  Refresh,
  Check,
  Close,
  RefreshRight,
} from '@element-plus/icons-vue'
import request from '@/api/request'

// 加载状态
const loading = ref(false)
const rejectLoading = ref(false)

// 表格数据
const tableData = ref<any[]>([])
const searchKey = ref('')
const filter = ref('0')
const page = ref(1)
const pageSize = ref(10)
const total = ref(0)

// 统计数据
const stats = reactive({
  pending: 0,
  approved: 0,
  rejected: 0,
})

// 驳回弹窗
const rejectDialogVisible = ref(false)
const rejectingComment = ref<any>(null)
const rejectReason = ref('')
const rejectNote = ref('')

// 获取评论列表
const fetchComments = async () => {
  loading.value = true
  try {
    const response = await request.get('/comment/list', {
      params: {
        status: filter.value,
        keyword: searchKey.value,
        page: page.value,
        size: pageSize.value,
      }
    })
    const data = response || (response as any).data
    tableData.value = data.records || []
    total.value = data.total || 0
  } catch (error) {
    console.error('获取评论列表失败:', error)
    tableData.value = []
    total.value = 0
  } finally {
    loading.value = false
  }
}

// 获取统计数据
const fetchStats = async () => {
  try {
    const response = await request.get('/comment/stats')
    const data = response || (response as any).data
    if (data) {
      stats.pending = data.pending || 0
      stats.approved = data.approved || 0
      stats.rejected = data.rejected || 0
    }
  } catch (error) {
    console.error('获取统计数据失败:', error)
  }
}

// 通过评论
const handleApprove = async (row: any) => {
  try {
    await request.put(`/comment/review/${row.id}`, {
      status: 1  // 1=通过
    })
    ElMessage.success('评论已通过')
    fetchComments()
    fetchStats()
  } catch (error) {
    console.error('操作失败:', error)
    ElMessage.error('操作失败')
  }
}

// 打开驳回弹窗
const handleReject = (row: any) => {
  rejectingComment.value = row
  rejectReason.value = ''
  rejectNote.value = ''
  rejectDialogVisible.value = true
}

// 确认驳回
const confirmReject = async () => {
  if (!rejectReason.value) {
    ElMessage.warning('请选择驳回原因')
    return
  }

  rejectLoading.value = true
  try {
    await request.put(`/comment/review/${rejectingComment.value.id}`, {
      status: 2,  // 2=驳回
      rejectReason: rejectReason.value,
      rejectNote: rejectNote.value,
    })
    ElMessage.success('评论已驳回')
    rejectDialogVisible.value = false
    fetchComments()
    fetchStats()
  } catch (error) {
    console.error('驳回失败:', error)
    ElMessage.error('操作失败')
  } finally {
    rejectLoading.value = false
  }
}

// 搜索
const handleSearch = () => {
  page.value = 1
  fetchComments()
}

// 重置
const handleReset = () => {
  searchKey.value = ''
  page.value = 1
  fetchComments()
}

// 筛选切换
const handleFilterChange = () => {
  page.value = 1
  searchKey.value = ''
  fetchComments()
}

// 分页
const handlePageChange = (newPage: number) => {
  page.value = newPage
  fetchComments()
}

const handleSizeChange = (newSize: number) => {
  pageSize.value = newSize
  page.value = 1
  fetchComments()
}

// 监听筛选变化
watch(filter, () => {
  page.value = 1
  searchKey.value = ''
  fetchComments()
})

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
  fetchComments()
  fetchStats()
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
  cursor: pointer;
  transition: all 0.3s;
  border: 2px solid transparent;
}

.stat-card:hover {
  transform: translateY(-2px);
}

.stat-card.active {
  border-color: #1A5276;
  box-shadow: 0 4px 15px rgba(26, 82, 118, 0.15);
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

.toolbar-right {
  display: flex;
  gap: 10px;
  align-items: center;
}

.search-input {
  width: 220px;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 8px;
}

.username {
  font-size: 13px;
  color: #333;
}

.comment-content {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.content-text {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.5;
  color: #333;
  font-size: 14px;
}

.comment-rating {
  margin-top: 2px;
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

/* 驳回弹窗 */
.reject-dialog p {
  margin-bottom: 15px;
  color: #666;
}

.reject-comment-preview {
  background: #f9f9f9;
  padding: 12px;
  border-radius: 8px;
  margin-bottom: 15px;
}

.reject-label {
  font-size: 12px;
  color: #999;
}

.reject-content {
  margin-top: 5px;
  font-size: 14px;
  color: #333;
  line-height: 1.5;
}

:deep(.el-table__row .el-button + .el-button) {
  margin-left: 4px;
}
</style>