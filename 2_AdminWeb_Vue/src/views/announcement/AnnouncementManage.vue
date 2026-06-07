<template>
  <div class="announcement-manage">
    <div class="header">
      <h2>校园公告管理</h2>
      <el-button type="primary" @click="dialogVisible = true">
        <el-icon><Plus /></el-icon> 发布新公告
      </el-button>
    </div>

    <el-table :data="announcements" stripe style="width: 100%" v-loading="loading">
      <el-table-column prop="id" label="ID" width="80" />
      <el-table-column prop="title" label="公告标题" />
      <el-table-column prop="publishDate" label="发布时间" width="200" />
      <el-table-column label="操作" width="200">
        <template #default="scope">
          <el-button size="small" type="primary" link @click="previewPdf(scope.row.pdfUrl)">预览PDF</el-button>
          <el-button size="small" type="danger" link @click="handleDelete(scope.row.id)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>

    <el-dialog v-model="dialogVisible" title="发布新公告" width="500px">
      <el-form :model="form" label-width="80px">
        <el-form-item label="公告标题">
          <el-input v-model="form.title" placeholder="请输入公告标题" />
        </el-form-item>
        <el-form-item label="PDF附件">
          <el-upload
            class="upload-demo"
            drag
            action="http://localhost:8080/announcement/upload"
            :data="{ title: form.title }"
            :headers="uploadHeaders"
            :on-success="handleUploadSuccess"
            :on-error="handleUploadError"
            :before-upload="beforeUpload"
            accept=".pdf"
            :limit="1"
          >
            <el-icon class="el-icon--upload"><upload-filled /></el-icon>
            <div class="el-upload__text">拖拽文件到此处，或 <em>点击上传</em></div>
            <template #tip>
              <div class="el-upload__tip">只能上传 PDF 文件</div>
            </template>
          </el-upload>
        </el-form-item>
      </el-form>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus, UploadFilled } from '@element-plus/icons-vue'
import request from '@/api/request' 

// 🌟 关键修改：显式指定数组类型为 any[]，不再是 never[]
const announcements = ref<any[]>([]) 
const loading = ref(false)
const dialogVisible = ref(false)
const form = ref({ title: '' })

const uploadHeaders = {
  Authorization: localStorage.getItem('token') || ''
}

const fetchList = async () => {
  loading.value = true
  try {
    // 🌟 关键修改：加上 as any 断言，避免 TypeScript 误认为这是 AxiosResponse
    const data = await request.get('/announcement/list') as any
    announcements.value = Array.isArray(data) ? data : []
  } catch (error) {
    console.error('获取列表失败', error)
  } finally {
    loading.value = false
  }
}

const beforeUpload = (file: File) => {
  if (!form.value.title) {
    ElMessage.warning('请先输入公告标题')
    return false
  }
  if (file.type !== 'application/pdf') {
    ElMessage.error('只允许上传 PDF 格式文件！')
    return false
  }
  return true
}

const handleUploadSuccess = (res: any) => {
  if (res.code === 200) {
    ElMessage.success('公告发布成功')
    dialogVisible.value = false
    form.value.title = ''
    fetchList()
  } else {
    ElMessage.error(res.message || '上传失败')
  }
}

const handleUploadError = () => {
  ElMessage.error('上传失败，请检查网络或服务器状态')
}

const handleDelete = (id: number) => {
  ElMessageBox.confirm('确定要删除这条公告吗?', '提示', { type: 'warning' }).then(async () => {
    try {
      await request.delete(`/announcement/${id}`)
      ElMessage.success('删除成功')
      fetchList()
    } catch (e) {
      // 错误由拦截器统一处理
    }
  })
}

const previewPdf = (url: string) => {
  window.open(url, '_blank')
}

onMounted(() => {
  fetchList()
})
</script>

<style scoped>
.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}
</style>