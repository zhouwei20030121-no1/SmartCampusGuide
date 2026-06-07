<template>
  <div class="page-container">
    <!-- 页面标题 -->
    <div class="page-header">
      <div>
        <h2>路线规划管理</h2>
        <p>管理校园导览路线、设置推荐游览方案</p>
      </div>
      <el-button type="primary" @click="handleAdd">
        <el-icon><Plus /></el-icon>
        新建路线
      </el-button>
    </div>

    <!-- 表格区域 -->
    <el-card class="table-card">
      <!-- 搜索栏 -->
      <div class="toolbar">
        <el-input
          v-model="searchKey"
          placeholder="搜索路线名称..."
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

      <!-- 表格 -->
      <el-table
        :data="tableData"
        border
        stripe
        v-loading="loading"
        class="route-table"
        empty-text="暂无路线数据"
      >
        <el-table-column prop="id" label="ID" width="70" />

        <el-table-column label="路线名称" min-width="160">
          <template #default="{ row }">
            <div class="route-name">
              <div class="route-icon">
                <el-icon :size="20"><MapLocation /></el-icon>
              </div>
              <span>{{ row.routeName }}</span>
            </div>
          </template>
        </el-table-column>

        <el-table-column label="适用人群" width="130">
          <template #default="{ row }">
            <el-tag :type="getAudienceType(row.targetAudience)" effect="plain">
              {{ row.targetAudience || '通用' }}
            </el-tag>
          </template>
        </el-table-column>

        <el-table-column label="途径景点" min-width="200">
          <template #default="{ row }">
            <div class="spot-tags">
              <el-tag
                v-for="(spot, index) in row.spots || []"
                :key="spot.id"
                size="small"
                type="info"
                effect="plain"
                class="spot-tag"
              >
                <span class="spot-order">{{ index + 1 }}</span>
                {{ spot.spotName }}
              </el-tag>
              <span v-if="!row.spots || row.spots.length === 0" class="empty-text">暂无景点</span>
            </div>
          </template>
        </el-table-column>

        <el-table-column label="预计耗时" width="100">
          <template #default="{ row }">
            <span class="time-text">{{ row.estimatedTime || '-' }} 分钟</span>
          </template>
        </el-table-column>

        <el-table-column label="状态" width="90" align="center">
          <template #default="{ row }">
            <el-switch
              :model-value="row.status === 1"
              @change="(val: boolean) => handleStatusChange(row, val)"
              active-text="启用"
              inactive-text="禁用"
              inline-prompt
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

        <el-table-column label="操作" width="220" fixed="right">
          <template #default="{ row }">
            <el-button size="small" type="primary" link @click="handleEdit(row)">
              <el-icon><Edit /></el-icon>
              编辑
            </el-button>
            <el-button size="small" type="warning" link @click="handleViewDetail(row)">
              <el-icon><View /></el-icon>
              详情
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

    <!-- 新增/编辑路线弹窗 -->
    <el-dialog
      v-model="dialogVisible"
      :title="dialogTitle"
      width="700px"
      :close-on-click-modal="false"
      @close="handleDialogClose"
    >
      <el-form
        ref="formRef"
        :model="formData"
        :rules="formRules"
        label-width="100px"
        class="route-form"
      >
        <div class="section-title">基本信息</div>

        <el-form-item label="路线名称" prop="routeName">
          <el-input
            v-model="formData.routeName"
            placeholder="请输入路线名称，如：经典校园文化游"
            maxlength="100"
            show-word-limit
          />
        </el-form-item>

        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="适用人群" prop="targetAudience">
              <el-select
                v-model="formData.targetAudience"
                placeholder="请选择适用人群"
                style="width: 100%"
              >
                <el-option label="新生入学" value="新生入学" />
                <el-option label="校友返校" value="校友返校" />
                <el-option label="游客参观" value="游客参观" />
                <el-option label="历史文化爱好者" value="历史文化爱好者" />
                <el-option label="自然风光爱好者" value="自然风光爱好者" />
                <el-option label="通用" value="通用" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="预计耗时">
              <el-input
                :model-value="estimatedTimeText"
                disabled
                style="width: 100%"
              />
              <span class="unit-text">（根据景点距离自动计算）</span>
            </el-form-item>
          </el-col>
        </el-row>

        <el-form-item label="状态" prop="status">
          <el-radio-group v-model="formData.status">
            <el-radio :label="1">启用</el-radio>
            <el-radio :label="0">禁用</el-radio>
          </el-radio-group>
        </el-form-item>

        <div class="section-title">路线描述</div>

        <el-form-item label="路线介绍" prop="description">
          <el-input
            v-model="formData.description"
            type="textarea"
            :rows="4"
            placeholder="请输入路线整体介绍，如：本路线将带您领略校园最具历史文化底蕴的景点..."
            maxlength="500"
            show-word-limit
          />
        </el-form-item>

        <div class="section-title">途径景点</div>

        <el-form-item label="选择景点" prop="spotIds">
          <div class="spot-selection-area">
            <div class="spot-select-header">
              <el-select
                v-model="selectedSpotId"
                placeholder="添加景点"
                style="width: 300px"
                filterable
                @change="addSpot"
              >
                <el-option
                  v-for="spot in availableSpots"
                  :key="spot.id"
                  :label="spot.name"
                  :value="spot.id"
                  :disabled="selectedSpotIds.includes(spot.id)"
                />
              </el-select>
              <span class="spot-count">已选 {{ selectedSpotIds.length }} 个景点</span>
            </div>

            <!-- 已选景点列表 -->
            <div class="selected-spots" v-if="selectedSpotIds.length > 0">
              <div
                v-for="(spotId, index) in selectedSpotIds"
                :key="spotId"
                class="spot-item"
              >
                <div class="spot-order-badge">{{ index + 1 }}</div>
                <div class="spot-info">
                  <span class="spot-name">{{ getSpotName(spotId) }}</span>
                  <span class="spot-category">{{ getSpotCategory(spotId) }}</span>
                </div>
                <div class="spot-actions">
                  <el-button
                    size="small"
                    :disabled="index === 0"
                    @click="moveSpot(index, index - 1)"
                    :icon="Top"
                    circle
                    title="上移"
                  />
                  <el-button
                    size="small"
                    :disabled="index === selectedSpotIds.length - 1"
                    @click="moveSpot(index, index + 1)"
                    :icon="Bottom"
                    circle
                    title="下移"
                  />
                  <el-button
                    size="small"
                    type="danger"
                    @click="removeSpot(index)"
                    :icon="Close"
                    circle
                    title="移除"
                  />
                </div>
              </div>
            </div>
            <div v-else class="empty-spots">
              <el-icon :size="40"><MapLocation /></el-icon>
              <span>请从上方选择要添加的景点</span>
            </div>
          </div>
        </el-form-item>
      </el-form>

      <template #footer>
        <div class="dialog-footer">
          <el-button @click="dialogVisible = false">取消</el-button>
          <el-button type="primary" @click="handleSubmit" :loading="submitLoading">
            {{ isEdit ? '保存修改' : '确认创建' }}
          </el-button>
        </div>
      </template>
    </el-dialog>

    <!-- 路线详情弹窗 -->
    <el-dialog
      v-model="detailDialogVisible"
      title="路线详细信息"
      width="700px"
      :close-on-click-modal="false"
    >
      <div v-if="currentRoute" class="route-detail">
        <el-descriptions :column="2" border>
          <el-descriptions-item label="路线名称" :span="2">
            <span class="detail-name">{{ currentRoute.routeName }}</span>
          </el-descriptions-item>
          <el-descriptions-item label="适用人群">
            <el-tag :type="getAudienceType(currentRoute.targetAudience)" size="large">
              {{ currentRoute.targetAudience || '通用' }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="状态">
            <el-tag :type="currentRoute.status === 1 ? 'success' : 'danger'" size="large">
              {{ currentRoute.status === 1 ? '启用' : '禁用' }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="预计耗时">
            {{ currentRoute.estimatedTime || '-' }} 分钟
          </el-descriptions-item>
          <el-descriptions-item label="更新时间">
            {{ formatDateTime(currentRoute.updateTime) }}
          </el-descriptions-item>
          <el-descriptions-item label="路线介绍" :span="2">
            <div class="description-text">{{ currentRoute.description || '暂无介绍' }}</div>
          </el-descriptions-item>
          <el-descriptions-item label="途径景点" :span="2">
            <div class="route-spots-detail">
              <div
                v-for="(spot, index) in currentRoute.spots || []"
                :key="spot.id"
                class="route-spot-item"
              >
                <div class="route-spot-order">{{ index + 1 }}</div>
                <div class="route-spot-info">
                  <span class="route-spot-name">{{ spot.spotName }}</span>
                  <span class="route-spot-desc">{{ spot.spotDescription || '暂无描述' }}</span>
                </div>
                <el-tag size="small" effect="plain">{{ spot.spotCategory }}</el-tag>
              </div>
              <div v-if="!currentRoute.spots || currentRoute.spots.length === 0" class="empty-text">
                暂无景点
              </div>
            </div>
          </el-descriptions-item>
        </el-descriptions>
      </div>

      <template #footer>
        <el-button @click="detailDialogVisible = false">关闭</el-button>
        <el-button type="primary" @click="handleEditFromDetail">编辑此路线</el-button>
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
  View,
  Delete,
  MapLocation,
  Top,
  Bottom,
  Close,
} from '@element-plus/icons-vue'
import request from '@/api/request'

// 加载状态
const loading = ref(false)
const submitLoading = ref(false)

// 表格数据
const tableData = ref<any[]>([])
const searchKey = ref('')
const page = ref(1)
const pageSize = ref(10)
const total = ref(0)

// 弹窗控制
const dialogVisible = ref(false)
const detailDialogVisible = ref(false)
const currentRoute = ref<any>(null)

// 表单引用
const formRef = ref<FormInstance>()

// 景点数据
const allSpots = ref<any[]>([])
const selectedSpotId = ref<number | null>(null)

// 计算已选景点ID列表
const selectedSpotIds = computed(() => {
  if (!formData.spotIds) return []
  return formData.spotIds.split(',').filter(Boolean).map(Number)
})

// 计算可选景点（排除已选的）
const availableSpots = computed(() => {
  return allSpots.value.filter(spot => !selectedSpotIds.value.includes(spot.id))
})

// 预计耗时显示文本
const estimatedTimeText = computed(() => {
  const count = selectedSpotIds.value.length
  if (count === 0) return '请先选择景点'
  if (count === 1) return '约 10 分钟'
  return '自动计算中...（保存时更新）'
})

// 编辑模式
const isEdit = computed(() => !!formData.id)
const dialogTitle = computed(() => isEdit.value ? '编辑路线' : '新建路线')

// 表单数据
const formData = reactive({
  id: null as number | null,
  routeName: '',
  targetAudience: '',
  status: 1,
  description: '',
  spotIds: '' as string,
})

// 表单验证规则
const formRules: FormRules = {
  routeName: [
    { required: true, message: '请输入路线名称', trigger: 'blur' },
    { min: 2, max: 100, message: '长度在 2 到 100 个字符', trigger: 'blur' }
  ],
  targetAudience: [
    { required: true, message: '请选择适用人群', trigger: 'change' }
  ],
  spotIds: [
    {
      validator: (_rule, value, callback) => {
        if (!value || value.split(',').filter(Boolean).length === 0) {
          callback(new Error('请至少选择一个景点'))
        } else {
          callback()
        }
      },
      trigger: 'change'
    }
  ],
}

// 获取景点名称
const getSpotName = (spotId: number) => {
  const spot = allSpots.value.find(s => s.id === spotId)
  return spot ? spot.name : `景点${spotId}`
}

// 获取景点分类
const getSpotCategory = (spotId: number) => {
  const spot = allSpots.value.find(s => s.id === spotId)
  return spot ? spot.category : ''
}

// 添加景点
const addSpot = (spotId: number) => {
  if (!spotId) return
  const currentIds = [...selectedSpotIds.value]
  currentIds.push(spotId)
  formData.spotIds = currentIds.join(',')
  selectedSpotId.value = null
}

// 移除景点
const removeSpot = (index: number) => {
  const currentIds = [...selectedSpotIds.value]
  currentIds.splice(index, 1)
  formData.spotIds = currentIds.join(',')
}

// 移动景点顺序
const moveSpot = (fromIndex: number, toIndex: number) => {
  const currentIds = [...selectedSpotIds.value]
  const item = currentIds.splice(fromIndex, 1)[0]
  currentIds.splice(toIndex, 0, item)
  formData.spotIds = currentIds.join(',')
}

// 获取路线列表
const fetchRoutes = async () => {
  loading.value = true
  try {
    const response = await request.get('/route/manage/list', {
      params: {
        keyword: searchKey.value,
        page: page.value,
        size: pageSize.value,
      }
    })
    const data = response || (response as any).data
    tableData.value = data.records || []
    total.value = data.total || 0
  } catch (error) {
    console.error('获取路线列表失败:', error)
    tableData.value = []
    total.value = 0
  } finally {
    loading.value = false
  }
}

// 获取景点列表
const fetchSpots = async () => {
  try {
    const response = await request.get('/spot/list', {
      params: { page: 1, size: 200 }
    })
    const data = response || (response as any).data
    allSpots.value = data.records || []
  } catch (error) {
    console.error('获取景点列表失败:', error)
  }
}

// 搜索
const handleSearch = () => {
  page.value = 1
  fetchRoutes()
}

// 重置
const handleReset = () => {
  searchKey.value = ''
  page.value = 1
  fetchRoutes()
}

// 分页
const handlePageChange = (newPage: number) => {
  page.value = newPage
  fetchRoutes()
}

const handleSizeChange = (newSize: number) => {
  pageSize.value = newSize
  page.value = 1
  fetchRoutes()
}

// 新增
const handleAdd = () => {
  resetFormData()
  dialogVisible.value = true
}

// 编辑
const handleEdit = async (row: any) => {
  try {
    loading.value = true
    const response = await request.get(`/route/manage/${row.id}`)
    const data = response || (response as any).data
    fillFormData(data || row)
    dialogVisible.value = true
  } catch (error) {
    console.error('获取路线详情失败:', error)
    fillFormData(row)
    dialogVisible.value = true
  } finally {
    loading.value = false
  }
}

// 从详情编辑
const handleEditFromDetail = () => {
  detailDialogVisible.value = false
  if (currentRoute.value) {
    fillFormData(currentRoute.value)
    dialogVisible.value = true
  }
}

// 填充表单
const fillFormData = (row: any) => {
  formData.id = row.id
  formData.routeName = row.routeName || ''
  formData.targetAudience = row.targetAudience || ''
  formData.status = row.status !== undefined ? row.status : 1
  formData.description = row.description || ''
  formData.spotIds = row.spotIds || ''
}

// 查看详情
const handleViewDetail = async (row: any) => {
  try {
    loading.value = true
    const response = await request.get(`/route/manage/${row.id}`)
    const data = response || (response as any).data
    currentRoute.value = data || row
    detailDialogVisible.value = true
  } catch (error) {
    console.error('获取路线详情失败:', error)
    currentRoute.value = row
    detailDialogVisible.value = true
  } finally {
    loading.value = false
  }
}

// 删除
const handleDelete = (row: any) => {
  ElMessageBox.confirm(
    `确定要删除路线 "${row.routeName}" 吗？`,
    '删除确认',
    {
      confirmButtonText: '确定删除',
      cancelButtonText: '取消',
      type: 'warning',
      confirmButtonClass: 'el-button--danger',
    }
  ).then(async () => {
    try {
      await request.delete(`/route/manage/${row.id}`)
      ElMessage.success('删除成功')
      if (tableData.value.length === 1 && page.value > 1) page.value--
      fetchRoutes()
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
    await request.patch(`/route/manage/${row.id}/status`, { status })
    row.status = status
    ElMessage.success(`已${value ? '启用' : '禁用'}路线：${row.routeName}`)
  } catch (error) {
    console.error('修改状态失败:', error)
    ElMessage.error('修改状态失败')
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
        const submitData = {
          routeName: formData.routeName,
          targetAudience: formData.targetAudience,
          status: formData.status,
          description: formData.description,
          spotIds: formData.spotIds,
        }

        if (isEdit.value) {
          await request.put(`/route/manage/${formData.id}`, submitData)
          ElMessage.success('路线更新成功')
        } else {
          await request.post('/route/manage', submitData)
          ElMessage.success('路线创建成功')
        }
        dialogVisible.value = false
        fetchRoutes()
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
  selectedSpotId.value = null
  if (formRef.value) formRef.value.resetFields()
}

// 重置表单
const resetFormData = () => {
  formData.id = null
  formData.routeName = ''
  formData.targetAudience = ''
  formData.status = 1
  formData.description = ''
  formData.spotIds = ''
  selectedSpotId.value = null
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
      hour: '2-digit', minute: '2-digit', second: '2-digit',
      hour12: false
    })
  } catch { return '-' }
}

// 适用人群标签类型
const getAudienceType = (audience: string) => {
  const typeMap: Record<string, string> = {
    '新生入学': 'success',
    '校友返校': 'warning',
    '游客参观': '',
    '历史文化爱好者': 'info',
    '自然风光爱好者': 'danger',
    '通用': '',
  }
  return typeMap[audience] || ''
}

onMounted(() => {
  fetchSpots()
  fetchRoutes()
})
</script>

<style scoped>
.page-container { display: flex; flex-direction: column; gap: 20px; }
.page-header { display: flex; justify-content: space-between; align-items: center; }
.page-header h2 { font-size: 28px; color: #1A5276; margin-bottom: 6px; }
.page-header p { color: #64748b; font-size: 14px; }
.table-card { border-radius: 20px; background: rgba(255,255,255,0.55); backdrop-filter: blur(14px); border: 1px solid rgba(255,255,255,0.45); }
.toolbar { display: flex; gap: 12px; margin-bottom: 20px; }
.search-input { width: 260px; }
.route-name { display: flex; align-items: center; gap: 10px; }
.route-icon { width: 32px; height: 32px; border-radius: 8px; background: rgba(26,82,118,0.1); display: flex; align-items: center; justify-content: center; color: #1A5276; }
.spot-tags { display: flex; flex-wrap: wrap; gap: 4px; }
.spot-tag { margin: 2px 0; }
.spot-order { display: inline-block; width: 18px; height: 18px; line-height: 18px; text-align: center; border-radius: 50%; background: #1A5276; color: #fff; font-size: 11px; margin-right: 4px; }
.empty-text { color: #999; font-size: 13px; }
.time-text { font-size: 13px; color: #666; }
.pagination-wrap { margin-top: 20px; display: flex; justify-content: flex-end; }
.route-form { max-height: 550px; overflow-y: auto; padding-right: 10px; }
.section-title { font-size: 15px; font-weight: 600; color: #1A5276; margin: 20px 0 14px 0; padding-bottom: 6px; border-bottom: 2px solid rgba(26,82,118,0.15); }
.unit-text { margin-left: 8px; color: #999; font-size: 12px; }
.spot-selection-area { width: 100%; }
.spot-select-header { display: flex; align-items: center; gap: 15px; margin-bottom: 12px; }
.spot-count { font-size: 13px; color: #666; }
.selected-spots { display: flex; flex-direction: column; gap: 8px; }
.spot-item { display: flex; align-items: center; gap: 12px; padding: 10px 14px; border: 1px solid rgba(26,82,118,0.12); border-radius: 10px; background: rgba(255,255,255,0.6); transition: all 0.2s; }
.spot-item:hover { border-color: rgba(26,82,118,0.3); background: rgba(26,82,118,0.03); }
.spot-order-badge { width: 28px; height: 28px; border-radius: 50%; background: #1A5276; color: #fff; display: flex; align-items: center; justify-content: center; font-size: 13px; font-weight: 600; flex-shrink: 0; }
.spot-info { flex: 1; display: flex; flex-direction: column; gap: 2px; }
.spot-name { font-size: 14px; font-weight: 500; color: #333; }
.spot-category { font-size: 12px; color: #999; }
.spot-actions { display: flex; gap: 4px; }
.empty-spots { display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 30px; color: #c0c4cc; border: 2px dashed #e4e7ed; border-radius: 10px; gap: 8px; }
.route-detail { max-height: 500px; overflow-y: auto; }
.detail-name { font-size: 18px; font-weight: 600; color: #1A5276; }
.description-text { line-height: 1.8; color: #666; }
.route-spots-detail { display: flex; flex-direction: column; gap: 10px; }
.route-spot-item { display: flex; align-items: center; gap: 12px; padding: 10px; border: 1px solid #e4e7ed; border-radius: 8px; }
.route-spot-order { width: 28px; height: 28px; border-radius: 50%; background: #1A5276; color: #fff; display: flex; align-items: center; justify-content: center; font-weight: 600; flex-shrink: 0; font-size: 13px; }
.route-spot-info { flex: 1; display: flex; flex-direction: column; gap: 2px; }
.route-spot-name { font-weight: 500; font-size: 14px; }
.route-spot-desc { font-size: 12px; color: #999; }
.dialog-footer { display: flex; justify-content: flex-end; gap: 12px; }
:deep(.el-table__row .el-button + .el-button) { margin-left: 4px; }
</style>