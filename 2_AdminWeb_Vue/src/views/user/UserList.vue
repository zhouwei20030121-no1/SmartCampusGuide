<template>
  <div class="page-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>用户管理</span>
          <el-button type="primary" @click="handleAdd">新增用户</el-button>
        </div>
      </template>

      <el-table :data="tableData" border stripe v-loading="loading">
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column prop="username" label="用户名" min-width="120" />
        <el-table-column prop="campusId" label="学号/工号" min-width="120" />
        <el-table-column prop="phone" label="手机号" min-width="120" />
        <el-table-column prop="role" label="角色" width="110">
          <template #default="{ row }">
            <el-tag :type="row.role === 1 ? 'danger' : (row.role === 2 ? 'warning' : 'info')">
              {{ getRoleName(row.role) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态" width="80">
          <template #default="{ row }">
            <el-tag :type="row.status === 0 ? 'success' : 'danger'">
              {{ row.status === 0 ? '正常' : '封禁' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="注册时间" min-width="160" />
        <el-table-column label="操作" width="150" fixed="right">
          <template #default="{ row }">
            <el-button size="small" type="primary" link @click="handleEdit(row)">编辑</el-button>
            <el-button size="small" type="danger" link @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="dialogVisible" :title="dialogTitle" width="500px">
      <el-form :model="form" label-width="100px">
        <el-form-item label="用户名">
          <el-input v-model="form.username" placeholder="请输入用户名 (必填)" />
        </el-form-item>
        <el-form-item label="密码">
          <el-input v-model="form.password" type="password" placeholder="编辑时留空则不修改密码" />
        </el-form-item>
        <el-form-item label="学号/工号">
          <el-input v-model="form.campusId" placeholder="请输入学号或工号" />
        </el-form-item>
        <el-form-item label="手机号">
          <el-input v-model="form.phone" placeholder="请输入手机号" />
        </el-form-item>
        <el-form-item label="系统角色">
          <el-select v-model="form.role" style="width: 100%">
            <el-option label="普通用户" :value="0" />
            <el-option label="系统管理员" :value="1" />
            <el-option label="内容运营人员" :value="2" />
          </el-select>
        </el-form-item>
        <el-form-item label="账号状态">
          <el-radio-group v-model="form.status">
            <el-radio :value="0">正常</el-radio>
            <el-radio :value="1">封禁</el-radio>
          </el-radio-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSave" :loading="submitLoading">确认保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import request from '@/api/request'

const loading = ref(false)
const submitLoading = ref(false)
const tableData = ref([])
const dialogVisible = ref(false)
const dialogTitle = ref('新增用户')

const form = reactive({
  id: null,
  username: '',
  password: '',
  campusId: '',
  phone: '',
  role: 0,
  status: 0
})

const getRoleName = (role: number) => {
  switch (role) {
    case 1: return '系统管理员'
    case 2: return '内容运营'
    default: return '普通用户'
  }
}

// 获取用户列表
const fetchUsers = async () => {
  loading.value = true
  try {
    const res = await request.get('/user/list')
    tableData.value = (res as any).records || res || []
  } catch (error) {
    console.error('获取列表失败', error)
  } finally {
    loading.value = false
  }
}

// 点击新增按钮
const handleAdd = () => {
  dialogTitle.value = '新增用户'
  Object.assign(form, { id: null, username: '', password: '', campusId: '', phone: '', role: 0, status: 0 })
  dialogVisible.value = true
}

// 点击编辑按钮
const handleEdit = (row: any) => {
  dialogTitle.value = '编辑用户'
  Object.assign(form, { ...row, password: '' })
  dialogVisible.value = true
}

// 确认保存数据
const handleSave = async () => {
  if (!form.username) {
    ElMessage.warning('用户名不能为空')
    return
  }
  submitLoading.value = true
  try {
    await request.post('/user/save', form)
    ElMessage.success('保存成功')
    dialogVisible.value = false
    fetchUsers()
  } catch (error) {
    console.error('保存失败', error)
  } finally {
    submitLoading.value = false
  }
}

// 确认删除数据
const handleDelete = (row: any) => {
  ElMessageBox.confirm(`确定要永久删除用户 "${row.username}" 吗？`, '高危操作警告', {
    type: 'warning',
    confirmButtonText: '确定删除',
    cancelButtonText: '取消'
  }).then(async () => {
    try {
      await request.delete(`/user/delete/${row.id}`)
      ElMessage.success('删除成功')
      fetchUsers()
    } catch (error) {
      console.error('删除失败', error)
    }
  }).catch(() => {})
}

onMounted(fetchUsers)
</script>

<style scoped>
.page-container { padding: 0; }
.card-header { display: flex; justify-content: space-between; align-items: center; }
</style>