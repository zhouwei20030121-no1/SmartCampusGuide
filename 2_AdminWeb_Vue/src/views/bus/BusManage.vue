<template>
  <div class="page-container">
    <div class="page-header">
      <div>
        <h2>校车路线管理</h2>
        <p>管理校园巴士线路、站点及运营信息</p>
      </div>
      <el-button type="primary" @click="openDialog(null)">
        <el-icon><Plus /></el-icon>
        新增线路
      </el-button>
    </div>

    <el-card class="table-card">
      <div class="toolbar">
        <el-input v-model="searchKey" placeholder="搜索线路名称..." clearable class="search-input" @keyup.enter="handleSearch" />
        <el-button type="primary" @click="handleSearch"><el-icon><Search /></el-icon> 搜索</el-button>
        <el-button @click="handleReset"><el-icon><Refresh /></el-icon> 重置</el-button>
      </div>

      <el-table :data="lines" border stripe v-loading="loading" empty-text="暂无校车线路">
        <el-table-column type="expand">
          <template #default="{ row }">
            <div class="expand-content">
              <div v-if="row.stations && Object.keys(row.stations).length > 0">
                <div v-for="(dirStations, dir) in row.stations" :key="dir" class="direction-group">
                  <h5 class="direction-title">{{ dir == 0 ? '🚌 上行/正向' : '🚌 下行/反向' }}</h5>
                  <div class="station-flow">
                    <div v-for="(station, index) in dirStations" :key="station.stationId" class="station-node">
                      <div class="node-dot" :class="{ 'node-start': index === 0, 'node-end': index === dirStations.length - 1 }">
                        {{ index + 1 }}
                      </div>
                      <span class="node-name">{{ station.stationName }}</span>
                      <div v-if="index < dirStations.length - 1" class="node-line"></div>
                    </div>
                  </div>
                </div>
              </div>
              <div v-else class="empty-stations">暂无站点信息</div>
            </div>
          </template>
        </el-table-column>

        <el-table-column prop="id" label="ID" width="50" align="center" />
        <el-table-column label="线路名称" min-width="130">
          <template #default="{ row }">
            <div class="line-name">
              <span class="line-icon">🚌</span>
              <span>{{ row.lineName }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="startStation" label="始发站" width="100" />
        <el-table-column label="运营时间" width="170">
          <template #default="{ row }">{{ formatTime(row.startTime) }} ~ {{ formatTime(row.endTime) }}</template>
        </el-table-column>
        <el-table-column label="间隔" width="70" align="center">
          <template #default="{ row }">
            <el-tag size="small" effect="plain">{{ row.intervalMins }}分</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="类型" width="95" align="center">
          <template #default="{ row }">
            <el-tag size="small" :type="row.directionType === 1 ? 'warning' : 'info'">
              {{ row.directionType === 1 ? '单向循环' : '往返线' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="启用" width="75" align="center">
          <template #default="{ row }">
            <el-switch :model-value="row.enabled === 1" @change="(val: boolean) => handleStatusChange(row, val)" size="small" style="--el-switch-on-color: #13ce66; --el-switch-off-color: #ff4949;" />
          </template>
        </el-table-column>
        <el-table-column label="操作" width="160" fixed="right">
          <template #default="{ row }">
            <el-button size="small" type="primary" link @click="openDialog(row)"><el-icon><Edit /></el-icon>编辑</el-button>
            <el-button size="small" type="danger" link @click="delLine(row.id)"><el-icon><Delete /></el-icon>删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pagination-wrap">
        <el-pagination v-model:current-page="page" v-model:page-size="pageSize" :page-sizes="[5,10,20,50]" :total="total" layout="total, sizes, prev, pager, next, jumper" @size-change="fetchLines" @current-change="fetchLines" />
      </div>
    </el-card>

    <el-dialog v-model="showDialog" :title="editingLine ? '编辑线路' : '新增线路'" width="750px" :close-on-click-modal="false">
      <el-form :model="form" label-width="90px">
        <div class="section-title">基本信息</div>
        <el-form-item label="线路名称">
          <el-input v-model="form.lineName" placeholder="如：八号门A线" maxlength="50" />
        </el-form-item>
        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="始发站">
              <el-select v-model="form.startStationId" placeholder="选择始发站" filterable style="width: 100%" @change="onStartStationChange">
                <el-option v-for="s in allStations" :key="s.id" :label="s.stationName" :value="s.id" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="终点站">
              <el-select v-model="form.endStationId" placeholder="选择终点站（可选）" filterable clearable style="width: 100%" @change="onEndStationChange">
                <el-option v-for="s in allStations" :key="s.id" :label="s.stationName" :value="s.id" />
              </el-select>
            </el-form-item>
          </el-col>
        </el-row>
        <el-form-item label="线路类型">
          <el-radio-group v-model="form.directionType">
            <el-radio :value="0">往返线</el-radio>
            <el-radio :value="1">单向循环线</el-radio>
          </el-radio-group>
        </el-form-item>

        <div class="section-title">运营信息</div>
        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="首班时间"><el-time-picker v-model="form.startTime" format="HH:mm" value-format="HH:mm:ss" style="width: 100%" /></el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="末班时间"><el-time-picker v-model="form.endTime" format="HH:mm" value-format="HH:mm:ss" style="width: 100%" /></el-form-item>
          </el-col>
        </el-row>
        <el-form-item label="发车间隔"><el-input-number v-model="form.intervalMins" :min="5" :max="60" /> 分钟</el-form-item>
        <el-form-item label="支付方式"><el-input v-model="form.fareInfo" placeholder="如：校园卡/微信/支付宝" /></el-form-item>
        <el-form-item label="备注"><el-input v-model="form.remark" type="textarea" :rows="2" placeholder="其他补充信息" /></el-form-item>

        <div class="section-title">站点管理</div>
        <el-tabs v-model="activeDirection">
          <el-tab-pane label="上行/正向" :name="0" />
          <el-tab-pane label="下行/反向" :name="1" v-if="form.directionType !== 1" />
        </el-tabs>
        <div class="station-manager">
          <div class="station-add-row">
            <el-select v-model="selectedStationId" placeholder="添加中间站点" filterable clearable style="flex: 1" @change="addStationToRoute">
              <el-option v-for="s in allStations" :key="s.id" :label="s.stationName" :value="s.id" />
            </el-select>
            <span class="station-count">共 {{ currentStations.length }} 站</span>
          </div>
          <div class="station-list" v-if="currentStations.length > 0">
            <div v-for="(station, index) in currentStations" :key="station.stationId + '-' + index" class="station-item">
              <div class="station-order" :class="{ 'order-start': index === 0, 'order-end': index === currentStations.length - 1 }">{{ index + 1 }}</div>
              <span class="station-name">{{ station.stationName }}</span>
              <div class="station-actions">
                <el-button size="small" :disabled="index === 0" @click="moveStation(index, -1)" :icon="Top" circle title="上移" />
                <el-button size="small" :disabled="index === currentStations.length - 1" @click="moveStation(index, 1)" :icon="Bottom" circle title="下移" />
                <el-button size="small" type="danger" @click="removeStation(index)" :icon="Delete" circle title="移除" />
              </div>
            </div>
          </div>
          <div v-else class="empty-stations-hint">请先选择始发站，再添加中间站点</div>
        </div>
      </el-form>
      <template #footer>
        <el-button @click="showDialog = false">取消</el-button>
        <el-button type="primary" @click="handleSave" :loading="saveLoading">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus, Search, Refresh, Edit, Delete, Top, Bottom } from '@element-plus/icons-vue'
import request from '@/api/request'

const loading = ref(false)
const saveLoading = ref(false)
const lines = ref<any[]>([])
const allStations = ref<any[]>([])
const showDialog = ref(false)
const editingLine = ref<any>(null)
const searchKey = ref('')
const page = ref(1)
const pageSize = ref(10)
const total = ref(0)
const activeDirection = ref(0)
const selectedStationId = ref<number | null>(null)

const form = reactive({
  lineName: '', startStationId: null as number | null, endStationId: null as number | null,
  startTime: null, endTime: null, intervalMins: 15, directionType: 0,
  fareInfo: '', remark: '',
})

const currentStations = ref<Array<{ stationId: number; stationName: string }>>([])
const upStations = ref<Array<{ stationId: number; stationName: string }>>([])
const downStations = ref<Array<{ stationId: number; stationName: string }>>([])

const formatTime = (time: string | null) => {
  if (!time) return '-'
  return time.length >= 5 ? time.substring(0, 5) : time
}

const getStationName = (id: number | null) => {
  if (!id) return ''
  const s = allStations.value.find((x: any) => x.id === id)
  return s ? s.stationName : ''
}

const fetchLines = async () => {
  loading.value = true
  try {
    const res = await request.get('/bus/line/list', { params: { keyword: searchKey.value, page: page.value, size: pageSize.value } })
    const data = res || (res as any).data
    const records = data?.records || []
    for (const line of records) {
      try {
        const stationRes = await request.get(`/bus/line/${line.id}/stations`)
        line.stations = stationRes || (stationRes as any).data
      } catch { line.stations = {} }
    }
    lines.value = records
    total.value = data?.total || 0
  } catch { lines.value = []; total.value = 0 } finally { loading.value = false }
}

const fetchStations = async () => {
  try { const res = await request.get('/bus/stations'); allStations.value = (res as any).data || res || [] } catch { allStations.value = [] }
}

const handleSearch = () => { page.value = 1; fetchLines() }
const handleReset = () => { searchKey.value = ''; page.value = 1; fetchLines() }

const onStartStationChange = (stationId: number) => {
  if (!stationId) return
  const name = getStationName(stationId)
  if (upStations.value.findIndex(s => s.stationId === stationId) === -1) upStations.value.unshift({ stationId, stationName: name })
  if (form.directionType !== 1 && downStations.value.length === 0) downStations.value.unshift({ stationId, stationName: name })
  syncCurrentStations()
}

const onEndStationChange = (stationId: number | null) => {
  if (!stationId) return
  const name = getStationName(stationId)
  if (upStations.value.findIndex(s => s.stationId === stationId) === -1) upStations.value.push({ stationId, stationName: name })
  if (form.directionType !== 1 && downStations.value.findIndex(s => s.stationId === stationId) === -1) downStations.value.push({ stationId, stationName: name })
  syncCurrentStations()
}

const syncCurrentStations = () => { currentStations.value = activeDirection.value === 0 ? [...upStations.value] : [...downStations.value] }
watch(activeDirection, () => syncCurrentStations())

const addStationToRoute = (stationId: number) => {
  if (!stationId) return
  const name = getStationName(stationId)
  if (activeDirection.value === 0) {
    const last = upStations.value[upStations.value.length - 1]
    last && form.endStationId && last.stationId === form.endStationId
      ? upStations.value.splice(upStations.value.length - 1, 0, { stationId, stationName: name })
      : upStations.value.push({ stationId, stationName: name })
  } else {
    const last = downStations.value[downStations.value.length - 1]
    last && form.endStationId && last.stationId === form.endStationId
      ? downStations.value.splice(downStations.value.length - 1, 0, { stationId, stationName: name })
      : downStations.value.push({ stationId, stationName: name })
  }
  syncCurrentStations(); selectedStationId.value = null
}

const removeStation = (index: number) => {
  activeDirection.value === 0 ? upStations.value.splice(index, 1) : downStations.value.splice(index, 1)
  syncCurrentStations()
}

const moveStation = (index: number, offset: number) => {
  const arr = activeDirection.value === 0 ? upStations.value : downStations.value
  const newIndex = index + offset
  if (newIndex < 0 || newIndex >= arr.length) return
  const item = arr.splice(index, 1)[0]; arr.splice(newIndex, 0, item)
  syncCurrentStations()
}

const openDialog = async (row: any) => {
  editingLine.value = row; activeDirection.value = 0; selectedStationId.value = null
  upStations.value = []; downStations.value = []
  if (row) {
    form.lineName = row.lineName || ''; form.startStationId = null; form.endStationId = null
    form.startTime = row.startTime ? `2000-01-01T${row.startTime}` : null
    form.endTime = row.endTime ? `2000-01-01T${row.endTime}` : null
    form.intervalMins = row.intervalMins || 15; form.directionType = row.directionType ?? 0
    form.fareInfo = row.fareInfo || ''; form.remark = row.remark || ''
    try {
      const res = await request.get(`/bus/line/${row.id}/stations`); const data = (res as any)?.data || res || {}
      upStations.value = (data[0] || []).map((s: any) => ({ stationId: s.stationId, stationName: s.stationName }))
      downStations.value = (data[1] || []).map((s: any) => ({ stationId: s.stationId, stationName: s.stationName }))
      if (upStations.value.length > 0) form.startStationId = upStations.value[0].stationId
      if (upStations.value.length > 1) form.endStationId = upStations.value[upStations.value.length - 1].stationId
    } catch (e) { console.error('加载站点失败:', e) }
  } else {
    Object.assign(form, { lineName: '', startStationId: null, endStationId: null, startTime: null, endTime: null, intervalMins: 15, directionType: 0, fareInfo: '', remark: '' })
  }
  syncCurrentStations(); showDialog.value = true
}

const handleSave = async () => {
  saveLoading.value = true
  try {
    const payload: any = {
      id: editingLine.value?.id || null, lineName: form.lineName,
      startStation: getStationName(form.startStationId), intervalMins: form.intervalMins,
      directionType: form.directionType, fareInfo: form.fareInfo, remark: form.remark,
      upStationIds: upStations.value.map(s => s.stationId).join(','),
      downStationIds: downStations.value.map(s => s.stationId).join(','),
    }
    if (form.startTime) { const ts = form.startTime as string; payload.startTime = ts.length >= 8 ? ts.substring(ts.length - 8) : ts } else { payload.startTime = null }
    if (form.endTime) { const ts = form.endTime as string; payload.endTime = ts.length >= 8 ? ts.substring(ts.length - 8) : ts } else { payload.endTime = null }
    await request.post('/bus/line', payload)
    ElMessage.success(editingLine.value ? '修改成功' : '新增成功'); showDialog.value = false; fetchLines()
  } catch (e) { console.error('保存失败:', e); ElMessage.error('保存失败') } finally { saveLoading.value = false }
}

const delLine = async (id: number) => {
  try { await ElMessageBox.confirm('确定删除该线路？', '提示', { type: 'warning' }); await request.delete(`/bus/line/${id}`); ElMessage.success('已删除'); fetchLines() } catch { /* 取消 */ }
}

const handleStatusChange = async (row: any, value: boolean) => {
  try { const enabled = value ? 1 : 0; await request.patch(`/bus/line/${row.id}/status`, { enabled }); row.enabled = enabled; ElMessage.success(`已${value ? '启用' : '停用'}`) } catch { ElMessage.error('操作失败'); row.enabled = row.enabled === 1 ? 0 : 1 }
}

onMounted(() => { fetchStations(); fetchLines() })
</script>

<style scoped>
.page-container { display: flex; flex-direction: column; gap: 20px; }
.page-header { display: flex; justify-content: space-between; align-items: center; }
.page-header h2 { font-size: 28px; color: #1A5276; margin-bottom: 6px; }
.page-header p { color: #64748b; font-size: 14px; }
.table-card { border-radius: 20px; background: rgba(255,255,255,0.55); backdrop-filter: blur(14px); border: 1px solid rgba(255,255,255,0.45); }
.toolbar { display: flex; gap: 12px; margin-bottom: 20px; }
.search-input { width: 260px; }
.line-name { display: flex; align-items: center; gap: 8px; }
.line-icon { font-size: 18px; }
.pagination-wrap { margin-top: 20px; display: flex; justify-content: flex-end; }

.expand-content { padding: 10px 20px; }
.direction-group { margin-bottom: 16px; }
.direction-title { margin: 0 0 12px; font-size: 14px; color: #1A5276; }
.station-flow { display: flex; flex-direction: column; gap: 0; padding-left: 10px; }
.station-node { display: flex; align-items: center; gap: 10px; position: relative; padding: 4px 0; }
.node-dot { width: 24px; height: 24px; border-radius: 50%; background: #e0e0e0; display: flex; align-items: center; justify-content: center; font-size: 11px; color: #666; flex-shrink: 0; }
.node-start { background: #27AE60; color: #fff; }
.node-end { background: #E74C3C; color: #fff; }
.node-name { font-size: 14px; color: #333; }
.node-line { position: absolute; left: 21px; top: 28px; width: 2px; height: 16px; background: #d0d0d0; }
.empty-stations { text-align: center; color: #999; padding: 20px; }

.section-title { font-size: 15px; font-weight: 600; color: #1A5276; margin: 16px 0 12px 0; padding-bottom: 6px; border-bottom: 2px solid rgba(26,82,118,0.15); }
.section-title:first-child { margin-top: 0; }

.station-manager { width: 100%; }
.station-add-row { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; }
.station-count { font-size: 13px; color: #666; white-space: nowrap; }
.station-list { display: flex; flex-direction: column; gap: 6px; max-height: 250px; overflow-y: auto; }
.station-item { display: flex; align-items: center; gap: 10px; padding: 8px 12px; border: 1px solid #e4e7ed; border-radius: 8px; background: #fafafa; }
.station-order { width: 24px; height: 24px; border-radius: 50%; background: #1A5276; color: #fff; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: 600; flex-shrink: 0; }
.order-start { background: #27AE60; }
.order-end { background: #E74C3C; }
.station-name { flex: 1; font-size: 14px; color: #333; }
.station-actions { display: flex; gap: 4px; }
.empty-stations-hint { text-align: center; color: #c0c4cc; padding: 30px; border: 2px dashed #e4e7ed; border-radius: 10px; }
</style>