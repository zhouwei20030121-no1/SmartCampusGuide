<template>
  <div class="page-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>路线规划管理</span>
          <el-button type="primary" @click="showDialog = true">新建路线</el-button>
        </div>
      </template>
      <el-table :data="tableData" border stripe>
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column prop="name" label="路线名称" />
        <el-table-column prop="spotIds" label="途径景点">
          <template #default="{ row }">
            <el-tag v-for="id in (row.spotIds || '').split(',')" :key="id" size="small" style="margin-right: 4px">
              景点{{ id }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="totalDistance" label="总距离(m)" />
        <el-table-column prop="estimatedMinutes" label="预计耗时(min)" />
        <el-table-column prop="status" label="状态">
          <template #default="{ row }">
            <el-tag :type="row.status === 'active' ? 'success' : 'info'">
              {{ row.status === 'active' ? '启用' : '停用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150">
          <template #default>
            <el-button size="small" type="primary" link>编辑</el-button>
            <el-button size="small" type="danger" link>删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="showDialog" title="新建路线" width="500px">
      <el-form :model="form" label-width="100px">
        <el-form-item label="路线名称">
          <el-input v-model="form.name" placeholder="如：经典校园游" />
        </el-form-item>
        <el-form-item label="途径景点">
          <el-select v-model="form.spotIds" multiple placeholder="选择景点" style="width: 100%">
            <el-option v-for="s in spotOptions" :key="s.id" :label="s.name" :value="s.id" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showDialog = false">取消</el-button>
        <el-button type="primary" @click="handleCreate">创建</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { ElMessage } from 'element-plus'

const tableData = ref<any[]>([])
const showDialog = ref(false)
const form = ref({ name: '', spotIds: [] as number[] })

const spotOptions = ref([
  { id: 1, name: '崇德湖' },
  { id: 2, name: '行署楼' },
  { id: 3, name: '共青团花园' },
])

const handleCreate = () => {
  showDialog.value = false
  ElMessage.success('路线创建成功')
}
</script>

<style scoped>
.page-container { padding: 0; }
.card-header { display: flex; justify-content: space-between; align-items: center; }
</style>
