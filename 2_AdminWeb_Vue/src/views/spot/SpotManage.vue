<template>
  <div class="page-container">

    <!-- 页面标题 -->
    <div class="page-header">
      <div>
        <h2>景点管理</h2>
        <p>管理校园景点、多媒体内容与展示信息</p>
      </div>

      <el-button type="primary" @click="handleAdd">
        <el-icon><Plus /></el-icon>
        新增景点
      </el-button>
    </div>

    <!-- 表格区域 -->
    <el-card class="table-card">

      <!-- 搜索栏 -->
      <div class="toolbar">
        <el-input
          v-model="searchKey"
          placeholder="搜索景点名称..."
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
        class="spot-table"
        empty-text="暂无景点数据"
      >

        <el-table-column prop="id" label="ID" width="80" />

        <el-table-column label="景点名称" min-width="180">
          <template #default="{ row }">
            <div class="spot-name">
              <div class="spot-avatar" :style="{ background: getAvatarColor(row.name) }">
                {{ row.name?.charAt(0) || '景' }}
              </div>
              <span>{{ row.name }}</span>
            </div>
          </template>
        </el-table-column>

        <el-table-column label="分类" width="120">
          <template #default="{ row }">
            <el-tag :type="getCategoryType(row.category)" effect="plain">
              {{ row.category || '未分类' }}
            </el-tag>
          </template>
        </el-table-column>

        <el-table-column prop="visitCount" label="访问量" width="100" sortable />

        <el-table-column label="评分" width="180">
          <template #default="{ row }">
            <div class="rating-cell">
              <el-rate
                :model-value="row.rating"
                disabled
                show-score
                text-color="#ff9900"
              />
            </div>
          </template>
        </el-table-column>

        <el-table-column label="状态" width="120" align="center">
          <template #default="{ row }">
            <div class="status-cell">
              <el-switch
                :model-value="row.status === 1"
                @change="(val: boolean) => handleStatusChange(row, val)"
                active-text="启用"
                inactive-text="禁用"
                inline-prompt
                style="--el-switch-on-color: #13ce66; --el-switch-off-color: #ff4949;"
              />
            </div>
          </template>
        </el-table-column>

        <el-table-column label="更新时间" width="180">
          <template #default="{ row }">
            <span class="time-text">{{ formatDateTime(row.updateTime) }}</span>
          </template>
        </el-table-column>

        <el-table-column label="操作" width="280" fixed="right">
          <template #default="{ row }">

            <el-button
              size="small"
              type="primary"
              link
              @click="handleEdit(row)"
            >
              <el-icon><Edit /></el-icon>
              编辑
            </el-button>

            <el-button
              size="small"
              type="warning"
              link
              @click="handleViewContent(row)"
            >
              <el-icon><View /></el-icon>
              详情
            </el-button>

            <el-button
              size="small"
              type="danger"
              link
              @click="handleDelete(row)"
            >
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

    <!-- 新增/编辑景点弹窗 -->
    <el-dialog
      v-model="dialogVisible"
      :title="dialogTitle"
      width="680px"
      :close-on-click-modal="false"
      @close="handleDialogClose"
    >

      <el-form
        ref="formRef"
        :model="formData"
        :rules="formRules"
        label-width="100px"
        class="spot-form"
      >

        <el-divider content-position="left">基本信息</el-divider>

        <el-form-item label="景点名称" prop="name">
          <el-input
            v-model="formData.name"
            placeholder="请输入景点名称"
            maxlength="50"
            show-word-limit
          />
        </el-form-item>

        <el-form-item label="景点分类" prop="category">
          <el-select
            v-model="formData.category"
            placeholder="请选择分类"
            style="width: 100%"
          >
            <el-option label="自然景观" value="自然景观" />
            <el-option label="历史建筑" value="历史建筑" />
            <el-option label="校园文化" value="校园文化" />
            <el-option label="教学设施" value="教学设施" />
            <el-option label="生活服务" value="生活服务" />
          </el-select>
        </el-form-item>

        <el-form-item label="状态" prop="status">
          <el-radio-group v-model="formData.status">
            <el-radio :label="1">启用</el-radio>
            <el-radio :label="0">禁用</el-radio>
          </el-radio-group>
        </el-form-item>

        <el-divider content-position="left">数据信息</el-divider>

        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="访问量" prop="visitCount">
              <el-input-number
                v-model="formData.visitCount"
                :min="0"
                :max="999999"
                style="width: 100%"
              />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="评分" prop="rating">
              <el-rate 
                v-model="formData.rating" 
                allow-half
                show-text
                :texts="['极差', '失望', '一般', '满意', '惊喜']"
              />
            </el-form-item>
          </el-col>
        </el-row>

        <el-divider content-position="left">详细信息</el-divider>

        <el-form-item label="景点介绍" prop="description">
          <el-input
            v-model="formData.description"
            type="textarea"
            :rows="4"
            placeholder="请输入景点介绍"
            maxlength="500"
            show-word-limit
          />
        </el-form-item>

        <!-- 封面图上传 + URL输入（双模式） -->
        <el-form-item label="封面图">
          <div class="cover-image-container">
            <!-- 图片预览 -->
            <div v-if="formData.coverImage" class="image-preview-section">
              <el-image
                :src="getFullImageUrl(formData.coverImage)"
                style="width: 200px; height: 150px"
                fit="cover"
                preview-teleported
                :preview-src-list="[getFullImageUrl(formData.coverImage)]"
              >
                <template #error>
                  <div class="image-slot">
                    <el-icon><PictureFilled /></el-icon>
                    <span>加载失败</span>
                  </div>
                </template>
              </el-image>
              <div class="image-info">
                <span class="image-url-text">当前图片：{{ formData.coverImage }}</span>
              </div>
              <el-button 
                type="danger" 
                size="small" 
                @click="removeCoverImage"
                :loading="deletingImage"
                style="margin-top: 10px;"
              >
                <el-icon><Delete /></el-icon>
                {{ deletingImage ? '删除中...' : '删除图片' }}
              </el-button>
            </div>

            <!-- 上传区域 -->
            <div class="upload-section">
              <!-- 方式1：文件上传 -->
              <el-upload
                class="spot-uploader"
                :action="uploadUrl"
                :show-file-list="false"
                :on-success="handleUploadSuccess"
                :on-error="handleUploadError"
                :before-upload="beforeImageUpload"
                accept="image/*"
                :disabled="uploadLoading"
              >
                <div class="upload-btn">
                  <el-icon v-if="!uploadLoading"><Upload /></el-icon>
                  <el-icon v-else class="is-loading"><Loading /></el-icon>
                  <span>{{ uploadLoading ? '上传中...' : '选择文件上传' }}</span>
                </div>
              </el-upload>

              <!-- 分隔线 -->
              <div class="divider-text">
                <span>或</span>
              </div>

              <!-- 方式2：手动输入URL -->
              <div class="url-input-section">
                <el-input
                  v-model="urlInput"
                  placeholder="输入图片URL地址"
                  clearable
                  @change="handleUrlInput"
                >
                  <template #append>
                    <el-button @click="applyUrl">应用</el-button>
                  </template>
                </el-input>
                <div class="url-tip">支持输入网络图片地址或本地路径，如：/images/spots/xxx.jpg</div>
              </div>
            </div>
          </div>
        </el-form-item>

        <el-divider content-position="left">地理信息</el-divider>

        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="纬度">
              <el-input-number
                v-model="formData.latitude"
                :precision="6"
                :min="-90"
                :max="90"
                style="width: 100%"
                placeholder="请输入纬度"
              />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="经度">
              <el-input-number
                v-model="formData.longitude"
                :precision="6"
                :min="-180"
                :max="180"
                style="width: 100%"
                placeholder="请输入经度"
              />
            </el-form-item>
          </el-col>
        </el-row>

        <el-form-item label="触发半径">
          <el-input-number
            v-model="formData.triggerRadius"
            :min="1"
            :max="1000"
            style="width: 100%"
            placeholder="地理围栏触发半径（米）"
          />
        </el-form-item>

      </el-form>

      <!-- 底部按钮 - 修改点1：去掉loading，改为disabled -->
      <template #footer>
        <div class="dialog-footer">
          <el-button @click="dialogVisible = false">取消</el-button>
          <el-button 
            type="primary" 
            @click="handleSubmit" 
            :disabled="submitLoading"
          >
            {{ submitLoading ? '保存中...' : (isEdit ? '保存修改' : '确认新增') }}
          </el-button>
        </div>
      </template>

    </el-dialog>

    <!-- 内容详情弹窗 -->
    <el-dialog
      v-model="contentDialogVisible"
      title="景点详细信息"
      width="750px"
      :close-on-click-modal="false"
    >
      <div v-if="currentSpot" class="spot-detail">
        <el-descriptions :column="2" border>
          <el-descriptions-item label="景点名称" :span="2">
            <span class="detail-name">{{ currentSpot.name }}</span>
          </el-descriptions-item>
          
          <el-descriptions-item label="分类">
            <el-tag :type="getCategoryType(currentSpot.category)" size="large">
              {{ currentSpot.category || '未分类' }}
            </el-tag>
          </el-descriptions-item>
          
          <el-descriptions-item label="状态">
            <el-tag :type="currentSpot.status === 1 ? 'success' : 'danger'" size="large">
              {{ currentSpot.status === 1 ? '启用' : '禁用' }}
            </el-tag>
          </el-descriptions-item>
          
          <el-descriptions-item label="访问量">
            <span class="detail-number">{{ currentSpot.visitCount }}</span>
          </el-descriptions-item>
          
          <el-descriptions-item label="评分">
            <el-rate
              :model-value="currentSpot.rating"
              disabled
              show-score
              text-color="#ff9900"
            />
          </el-descriptions-item>
          
          <el-descriptions-item label="经纬度">
            {{ currentSpot.latitude }}, {{ currentSpot.longitude }}
          </el-descriptions-item>
          
          <el-descriptions-item label="触发半径">
            {{ currentSpot.triggerRadius || 0 }} 米
          </el-descriptions-item>
          
          <el-descriptions-item label="景点介绍" :span="2">
            <div class="description-text">
              {{ currentSpot.description || '暂无介绍' }}
            </div>
          </el-descriptions-item>
          
          <el-descriptions-item label="封面图" :span="2">
            <div class="detail-cover-image">
              <el-image
                v-if="currentSpot.coverImage"
                :src="getFullImageUrl(currentSpot.coverImage)"
                style="width: 300px; height: 200px"
                fit="cover"
                :preview-src-list="[getFullImageUrl(currentSpot.coverImage)]"
                preview-teleported
              >
                <template #error>
                  <div class="image-error">
                    <el-icon :size="48"><PictureFilled /></el-icon>
                    <span>图片加载失败</span>
                  </div>
                </template>
              </el-image>
              <div v-else class="no-image">
                <el-icon :size="48"><PictureFilled /></el-icon>
                <span>暂无封面图</span>
              </div>
            </div>
          </el-descriptions-item>
          
          <el-descriptions-item label="创建时间">
            {{ formatDateTime(currentSpot.createTime) }}
          </el-descriptions-item>
          
          <el-descriptions-item label="更新时间">
            {{ formatDateTime(currentSpot.updateTime) }}
          </el-descriptions-item>
        </el-descriptions>
      </div>

      <template #footer>
        <el-button @click="contentDialogVisible = false">关闭</el-button>
        <el-button type="primary" @click="handleEditFromDetail">
          编辑此景点
        </el-button>
      </template>
    </el-dialog>

  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import type { FormInstance, FormRules, UploadProps } from 'element-plus'
import {
  Plus,
  Search,
  Refresh,
  Edit,
  View,
  Delete,
  PictureFilled,
  Loading,
  Upload,
} from '@element-plus/icons-vue'
import request from '@/api/request'

// 加载状态
const loading = ref(false)
const submitLoading = ref(false)
const uploadLoading = ref(false)
const deletingImage = ref(false)

// 表格数据
const tableData = ref<any[]>([])
const searchKey = ref('')
const page = ref(1)
const pageSize = ref(10)
const total = ref(0)

// 弹窗控制
const dialogVisible = ref(false)
const contentDialogVisible = ref(false)
const currentSpot = ref<any>(null)

// 表单引用
const formRef = ref<FormInstance>()

// 上传配置
const uploadUrl = ref('/api/upload/spot-image')

// URL输入
const urlInput = ref('')

// 计算是否为编辑模式
const isEdit = computed(() => !!formData.id)

// 对话框标题
const dialogTitle = computed(() => isEdit.value ? '编辑景点' : '新增景点')

// 表单数据
const formData = reactive({
  id: null as number | null,
  name: '',
  category: '',
  visitCount: 0,
  rating: 5,
  status: 1,
  description: '',
  coverImage: '',
  latitude: null as number | null,
  longitude: null as number | null,
  triggerRadius: 50,
})

// 表单验证规则
const formRules: FormRules = {
  name: [
    { required: true, message: '请输入景点名称', trigger: 'blur' },
    { min: 2, max: 50, message: '长度在 2 到 50 个字符', trigger: 'blur' }
  ],
  category: [
    { required: true, message: '请选择景点分类', trigger: 'change' }
  ],
  visitCount: [
    { required: true, message: '请输入访问量', trigger: 'blur' },
    { type: 'number', min: 0, message: '访问量不能为负数', trigger: 'blur' }
  ],
  rating: [
    { required: true, message: '请设置评分', trigger: 'change' }
  ],
  status: [
    { required: true, message: '请选择状态', trigger: 'change' }
  ],
}

// 获取完整的图片URL
const getFullImageUrl = (url: string) => {
  if (!url) return ''
  
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url
  }
  
  if (url.startsWith('/')) {
    return 'http://localhost:8080' + url
  }
  
  return url
}

// 判断是否为本地图片
const isLocalImage = (url: string) => {
  return url && url.startsWith('/images/spots/')
}

// 获取景点列表
const fetchSpots = async () => {
  loading.value = true

  try {
    const response = await request.get('/spot/list', {
      params: {
        keyword: searchKey.value,
        page: page.value,
        size: pageSize.value,
      },
    })

    const data = response.data || response
    tableData.value = data.records || []
    total.value = data.total || 0

  } catch (error) {
    console.error('获取景点列表失败:', error)
    ElMessage.error('获取景点列表失败')
    tableData.value = []
    total.value = 0
  } finally {
    loading.value = false
  }
}

// 搜索
const handleSearch = () => {
  page.value = 1
  fetchSpots()
}

// 重置搜索
const handleReset = () => {
  searchKey.value = ''
  page.value = 1
  fetchSpots()
}

// 分页处理
const handlePageChange = (newPage: number) => {
  page.value = newPage
  fetchSpots()
}

const handleSizeChange = (newSize: number) => {
  pageSize.value = newSize
  page.value = 1
  fetchSpots()
}

// 新增景点
const handleAdd = () => {
  resetFormData()
  dialogVisible.value = true
}

// 编辑景点
const handleEdit = async (row: any) => {
  try {
    loading.value = true
    const response = await request.get(`/spot/${row.id}`)
    const latestData = response.data || response
    console.log('编辑景点 - 获取到最新数据:', latestData)
    fillFormData(latestData)
    dialogVisible.value = true
  } catch (error) {
    console.error('获取景点数据失败，使用缓存数据:', error)
    fillFormData(row)
    dialogVisible.value = true
  } finally {
    loading.value = false
  }
}

// 从详情弹窗编辑
const handleEditFromDetail = () => {
  contentDialogVisible.value = false
  if (currentSpot.value) {
    fillFormData(currentSpot.value)
    dialogVisible.value = true
  }
}

// 填充表单数据
const fillFormData = (row: any) => {
  formData.id = row.id
  formData.name = row.name || ''
  formData.category = row.category || ''
  formData.visitCount = row.visitCount || 0
  formData.rating = row.rating || 5
  formData.status = row.status !== undefined ? row.status : 1
  formData.description = row.description || ''
  
  const coverImage = row.coverImage || ''
  formData.coverImage = coverImage
  urlInput.value = coverImage
  
  formData.latitude = row.latitude
  formData.longitude = row.longitude
  formData.triggerRadius = row.triggerRadius || 50
}

// 查看景点内容
const handleViewContent = async (row: any) => {
  try {
    loading.value = true
    const response = await request.get(`/spot/${row.id}`)
    const data = response.data || response
    currentSpot.value = data
    contentDialogVisible.value = true
  } catch (error) {
    console.error('获取景点详情失败:', error)
    ElMessage.error('获取景点详情失败')
  } finally {
    loading.value = false
  }
}

// 删除景点
const handleDelete = (row: any) => {
  ElMessageBox.confirm(
    `确定要删除景点 "${row.name}" 吗？\n删除后数据将无法恢复。`,
    '删除确认',
    {
      confirmButtonText: '确定删除',
      cancelButtonText: '取消',
      type: 'warning',
      confirmButtonClass: 'el-button--danger',
    }
  )
    .then(async () => {
      try {
        // 如果有本地图片，先删除图片文件
        if (row.coverImage && isLocalImage(row.coverImage)) {
          try {
            await request.delete('/upload/spot-image', {
              params: { url: row.coverImage }
            })
            console.log('景点图片已删除:', row.coverImage)
          } catch (error) {
            console.error('删除图片文件失败:', error)
          }
        }
        
        await request.delete(`/spot/${row.id}`)
        ElMessage.success('删除成功')
        
        if (tableData.value.length === 1 && page.value > 1) {
          page.value--
        }
        
        fetchSpots()
      } catch (error) {
        console.error('删除失败:', error)
        ElMessage.error('删除失败，请重试')
      }
    })
    .catch(() => {})
}

// 修改状态
const handleStatusChange = async (row: any, value: boolean) => {
  try {
    const status = value ? 1 : 0
    await request.patch(`/spot/${row.id}/status`, { status })
    row.status = status
    ElMessage.success(`已${value ? '启用' : '禁用'}景点：${row.name}`)
  } catch (error) {
    console.error('修改状态失败:', error)
    ElMessage.error('修改状态失败')
    row.status = row.status === 1 ? 0 : 1
  }
}

// 图片上传成功处理
const handleUploadSuccess: UploadProps['onSuccess'] = async (response: any) => {
  uploadLoading.value = false
  console.log('上传响应:', response)
  
  let imageUrl = ''
  
  if (typeof response === 'string') {
    imageUrl = response
  } else if (response.url) {
    imageUrl = response.url
  } else if (response.data && response.data.url) {
    imageUrl = response.data.url
  } else if (response.data && typeof response.data === 'string') {
    imageUrl = response.data
  }
  
  if (imageUrl) {
    // 如果之前有本地图片，先删除旧图片
    if (formData.coverImage && isLocalImage(formData.coverImage)) {
      try {
        await request.delete('/upload/spot-image', {
          params: { url: formData.coverImage }
        })
        console.log('旧图片已删除:', formData.coverImage)
      } catch (error) {
        console.error('删除旧图片失败:', error)
      }
    }
    
    // 更新表单中的图片URL
    formData.coverImage = imageUrl
    urlInput.value = imageUrl
    
    // 如果是编辑已有景点，立即保存到数据库
    if (isEdit.value && formData.id) {
      try {
        await request.put(`/spot/${formData.id}`, { coverImage: imageUrl })
        console.log('图片URL已保存到数据库')
        ElMessage.success('封面上传成功并已保存')
      } catch (error) {
        console.error('保存图片URL失败:', error)
        ElMessage.success('封面上传成功（请点击"保存修改"保存其他信息）')
      }
    } else {
      ElMessage.success('封面上传成功')
    }
  } else {
    console.error('无法解析图片URL:', response)
    ElMessage.error('上传失败，未获取到图片地址')
  }
}

// 图片上传失败处理
const handleUploadError: UploadProps['onError'] = (error) => {
  uploadLoading.value = false
  console.error('图片上传失败:', error)
  ElMessage.error('图片上传失败，请重试')
}

// 上传前验证
const beforeImageUpload: UploadProps['beforeUpload'] = (file) => {
  const isImage = file.type.startsWith('image/')
  if (!isImage) {
    ElMessage.error('只能上传图片文件！')
    return false
  }
  
  const isLt5M = file.size / 1024 / 1024 < 5
  if (!isLt5M) {
    ElMessage.error('图片大小不能超过 5MB！')
    return false
  }
  
  uploadLoading.value = true
  return true
}

// 手动输入URL
const handleUrlInput = (value: string) => {
  urlInput.value = value
}

// 应用URL
const applyUrl = () => {
  if (urlInput.value && urlInput.value.trim()) {
    formData.coverImage = urlInput.value.trim()
    ElMessage.success('URL已应用')
  } else {
    formData.coverImage = ''
    ElMessage.warning('URL为空，已清空封面图')
  }
}

// 删除封面图
const removeCoverImage = async () => {
  const imageUrl = formData.coverImage
  
  // 如果是本地图片，调用后端接口删除物理文件
  if (imageUrl && isLocalImage(imageUrl)) {
    try {
      deletingImage.value = true
      await request.delete('/upload/spot-image', {
        params: { url: imageUrl }
      })
      console.log('图片文件已删除:', imageUrl)
      ElMessage.success('封面图已删除（包括物理文件）')
    } catch (error) {
      console.error('删除图片文件失败:', error)
      ElMessage.warning('封面图已删除（物理文件删除失败）')
    } finally {
      deletingImage.value = false
    }
  } else {
    ElMessage.success('封面图已删除')
  }
  
  // 清除表单中的URL
  formData.coverImage = ''
  urlInput.value = ''
  
  // 如果是编辑模式，更新数据库
  if (isEdit.value && formData.id) {
    try {
      await request.put(`/spot/${formData.id}`, { coverImage: '' })
      console.log('数据库中的图片URL已清除')
    } catch (error) {
      console.error('更新数据库失败:', error)
    }
  }
}

// 提交表单 - 修改点2：添加防重复提交
const handleSubmit = async () => {
  if (!formRef.value) return
  
  // 防止重复提交
  if (submitLoading.value) return
  
  await formRef.value.validate(async (valid) => {
    if (valid) {
      submitLoading.value = true
      
      try {
        if (isEdit.value) {
          await request.put(`/spot/${formData.id}`, formData)
          ElMessage.success('编辑景点成功')
        } else {
          await request.post('/spot', formData)
          ElMessage.success('新增景点成功')
        }
        
        dialogVisible.value = false
        fetchSpots()
      } catch (error) {
        console.error('提交失败:', error)
        ElMessage.error('操作失败，请重试')
      } finally {
        submitLoading.value = false
      }
    }
  })
}

// 对话框关闭时的处理
const handleDialogClose = () => {
  uploadLoading.value = false
  deletingImage.value = false
  if (formRef.value) {
    formRef.value.resetFields()
  }
}

// 重置表单数据
const resetFormData = () => {
  formData.id = null
  formData.name = ''
  formData.category = ''
  formData.visitCount = 0
  formData.rating = 5
  formData.status = 1
  formData.description = ''
  formData.coverImage = ''
  formData.latitude = null
  formData.longitude = null
  formData.triggerRadius = 50
  urlInput.value = ''
  uploadLoading.value = false
  deletingImage.value = false
  
  if (formRef.value) {
    formRef.value.resetFields()
  }
}

// 格式化日期时间
const formatDateTime = (dateTime: string | null) => {
  if (!dateTime) return '-'
  
  try {
    const date = new Date(dateTime)
    if (isNaN(date.getTime())) {
      return '-'
    }
    
    return date.toLocaleString('zh-CN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false
    })
  } catch (error) {
    console.error('日期格式化错误:', error)
    return '-'
  }
}

// 获取头像背景色
const getAvatarColor = (name: string) => {
  const colors = [
    '#1890ff', '#52c41a', '#fa8c16', '#f5222d', 
    '#722ed1', '#13c2c2', '#eb2f96', '#faad14'
  ]
  if (!name) return colors[0]
  const index = name.charCodeAt(0) % colors.length
  return colors[index]
}

// 获取分类标签类型
const getCategoryType = (category: string) => {
  const typeMap: Record<string, string> = {
    '自然景观': 'success',
    '历史建筑': 'warning',
    '校园文化': 'info',
    '教学设施': '',
    '生活服务': 'danger',
  }
  return typeMap[category] || 'info'
}

onMounted(() => {
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

.table-card {
  border-radius: 20px;
  background: rgba(255,255,255,0.55);
  backdrop-filter: blur(14px);
  border: 1px solid rgba(255,255,255,0.45);
}

.toolbar {
  display: flex;
  gap: 12px;
  margin-bottom: 20px;
}

.search-input {
  width: 260px;
}

.spot-name {
  display: flex;
  align-items: center;
  gap: 12px;
}

.spot-avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 16px;
  flex-shrink: 0;
}

.rating-cell {
  display: flex;
  align-items: center;
}

.status-cell {
  display: flex;
  justify-content: center;
  align-items: center;
}

:deep(.el-switch__label) {
  font-size: 12px;
}

:deep(.el-switch) {
  --el-switch-width: 60px;
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

.spot-form {
  max-height: 500px;
  overflow-y: auto;
  padding-right: 10px;
}

.spot-detail {
  max-height: 500px;
  overflow-y: auto;
}

.detail-name {
  font-size: 18px;
  font-weight: 600;
  color: #1A5276;
}

.detail-number {
  font-size: 16px;
  font-weight: 500;
  color: #1890ff;
}

.description-text {
  line-height: 1.8;
  color: #666;
  min-height: 60px;
}

.detail-cover-image {
  display: flex;
  justify-content: center;
}

/* ==================== 封面上传样式 ==================== */
.cover-image-container {
  width: 100%;
}

.image-preview-section {
  margin-bottom: 15px;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
}

.image-info {
  margin-top: 5px;
  margin-bottom: 5px;
}

.image-url-text {
  font-size: 12px;
  color: #999;
  word-break: break-all;
}

.image-slot {
  width: 200px;
  height: 150px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: #f5f7fa;
  color: #c0c4cc;
  font-size: 14px;
  gap: 8px;
}

.upload-section {
  border: 1px solid #e4e7ed;
  border-radius: 8px;
  padding: 20px;
  background: #fafafa;
}

.upload-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 10px 20px;
  border: 2px dashed #d9d9d9;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.3s;
  color: #606266;
}

.upload-btn:hover {
  border-color: #1A5276;
  color: #1A5276;
  background: #f0f7ff;
}

.spot-uploader {
  width: 100%;
}

.divider-text {
  display: flex;
  align-items: center;
  margin: 15px 0;
  color: #999;
  font-size: 14px;
}

.divider-text::before,
.divider-text::after {
  content: '';
  flex: 1;
  border-bottom: 1px solid #e4e7ed;
}

.divider-text span {
  padding: 0 15px;
}

.url-input-section {
  width: 100%;
}

.url-tip {
  font-size: 12px;
  color: #999;
  margin-top: 5px;
}

.image-error,
.no-image {
  width: 300px;
  height: 200px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: #f5f5f5;
  color: #999;
  gap: 8px;
  border: 1px dashed #d9d9d9;
  border-radius: 4px;
}

.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

:deep(.el-descriptions__label) {
  width: 100px;
  font-weight: 600;
}

:deep(.el-divider__text) {
  font-weight: 600;
  color: #1A5276;
}

:deep(.el-table__row .el-button + .el-button) {
  margin-left: 4px;
}

.is-loading {
  animation: rotating 2s linear infinite;
}

@keyframes rotating {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}
</style>