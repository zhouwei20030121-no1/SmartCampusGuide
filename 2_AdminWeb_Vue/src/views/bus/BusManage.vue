<template>
  <div class="page-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>校车路线管理</span>
          <el-button type="primary" @click="openDialog(null)">新增线路</el-button>
        </div>
      </template>
      <el-table :data="lines" border stripe v-loading="loading">
        <el-table-column prop="id" label="ID" width="50" />
        <el-table-column prop="lineName" label="线路名称" width="150" />
        <el-table-column prop="startStation" label="始发站" width="120" />
        <el-table-column prop="startTime" label="首班" width="70" />
        <el-table-column prop="endTime" label="末班" width="70" />
        <el-table-column prop="intervalMins" label="间隔(分)" width="70" />
        <el-table-column label="类型" width="80">
          <template #default="{ row }">
            <el-tag size="small" :type="row.directionType === 1 ? 'warning' : ''">
              {{ row.directionType === 1 ? '循环线' : '往返线' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="fareInfo" label="支付方式" width="140" />
        <el-table-column label="操作" width="120">
          <template #default="{ row }">
            <el-button size="small" type="primary" link @click="openDialog(row)">编辑</el-button>
            <el-button size="small" type="danger" link @click="delLine(row.id)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="showDialog" :title="editingLine ? '编辑线路' : '新增线路'" width="500px">
      <el-form :model="form" label-width="90px">
        <el-form-item label="线路名称"><el-input v-model="form.lineName" /></el-form-item>
        <el-form-item label="始发站"><el-input v-model="form.startStation" /></el-form-item>
        <el-form-item label="首班时间"><el-time-picker v-model="form.startTime" format="HH:mm" value-format="HH:mm:ss" /></el-form-item>
        <el-form-item label="末班时间"><el-time-picker v-model="form.endTime" format="HH:mm" value-format="HH:mm:ss" /></el-form-item>
        <el-form-item label="发车间隔"><el-input-number v-model="form.intervalMins" :min="5" :max="60" /> 分钟</el-form-item>
        <el-form-item label="线路类型">
          <el-radio-group v-model="form.directionType">
            <el-radio :value="0">往返线</el-radio>
            <el-radio :value="1">单向循环线</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="支付方式"><el-input v-model="form.fareInfo" /></el-form-item>
        <el-form-item label="备注"><el-input v-model="form.remark" type="textarea" :rows="2" /></el-form-item>
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
import { ElMessage, ElMessageBox } from 'element-plus'
import request from '@/api/request'

const loading = ref(false)
const lines = ref<any[]>([])
const showDialog = ref(false)
const editingLine = ref<any>(null)
const form = reactive({
  lineName: '', startStation: '', startTime: null, endTime: null,
  intervalMins: 15, directionType: 0, fareInfo: '', remark: '',
})

const fetchLines = async () => {
  loading.value = true
  try {
    const res = await request.get('/bus/lines/simple')
    lines.value = (res as any).data || []
  } finally { loading.value = false }
}

const openDialog = (row: any) => {
  editingLine.value = row
  if (row) {
    Object.assign(form, { ...row, startTime: row.startTime ? `2000-01-01T${row.startTime}` : null, endTime: row.endTime ? `2000-01-01T${row.endTime}` : null })
  } else {
    Object.assign(form, { lineName: '', startStation: '', startTime: null, endTime: null, intervalMins: 15, directionType: 0, fareInfo: '', remark: '' })
  }
  showDialog.value = true
}

const handleSave = async () => {
  const payload = {
    ...form,
    id: editingLine.value?.id,
    startTime: form.startTime ? (form.startTime as string).slice(11, 19) : null,
    endTime: form.endTime ? (form.endTime as string).slice(11, 19) : null,
  }
  try {
    await request.post('/bus/line', payload)
    ElMessage.success('保存成功')
    showDialog.value = false
    fetchLines()
  } catch { ElMessage.error('保存失败') }
}

const delLine = async (id: number) => {
  await ElMessageBox.confirm('确定删除？', '提示', { type: 'warning' })
  try { await request.delete(`/bus/line/${id}`); ElMessage.success('已删除'); fetchLines() } catch { /* canceled */ }
}

onMounted(fetchLines)
</script>

<style scoped>
.page-container { padding: 0; }
.card-header { display: flex; justify-content: space-between; align-items: center; }
</style>
