<template>
  <div class="dashboard">
    <el-row :gutter="20">
      <el-col :span="6" v-for="card in statCards" :key="card.label">
        <el-card class="stat-card" shadow="hover">
          <div class="stat-content">
            <div class="stat-icon" :style="{ backgroundColor: card.bg }">
              <el-icon :size="24"><component :is="card.icon" /></el-icon>
            </div>
            <div class="stat-info">
              <div class="stat-label">{{ card.label }}</div>
              <div class="stat-value">{{ card.value }}</div>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="20" style="margin-top: 20px">
      <el-col :span="16">
        <el-card>
          <template #header>近7日访问趋势</template>
          <div class="chart-placeholder">
            <div class="chart-icon">ECharts 图表区域</div>
            <div class="chart-hint">TODO: 接入 ECharts 折线图展示访问趋势</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card>
          <template #header>热门景点 TOP5</template>
          <el-table :data="topSpots" stripe size="small">
            <el-table-column type="index" label="排名" width="60" />
            <el-table-column prop="name" label="景点名称" />
            <el-table-column prop="count" label="访问量" width="80" />
          </el-table>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { User, Location, Headset, ChatDotSquare } from '@element-plus/icons-vue'

const statCards = [
  { label: '注册用户', value: '1,280', icon: 'User', bg: '#4A90E2' },
  { label: '景点总数', value: '48', icon: 'Location', bg: '#27AE60' },
  { label: '累计讲解', value: '3,520', icon: 'Headset', bg: '#F39C12' },
  { label: 'AI问答', value: '856', icon: 'ChatDotSquare', bg: '#E74C3C' },
]

const topSpots = ref([
  { name: '崇德湖', count: 642 },
  { name: '行署楼', count: 518 },
  { name: '共青团花园', count: 435 },
  { name: '中心图书馆', count: 398 },
  { name: '竹园食堂', count: 276 },
])
</script>

<style scoped>
.dashboard { padding: 0; }
.stat-card { cursor: pointer; }
.stat-content { display: flex; align-items: center; gap: 16px; }
.stat-icon {
  width: 56px; height: 56px; border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
  color: #fff;
}
.stat-label { font-size: 13px; color: #999; }
.stat-value { font-size: 28px; font-weight: 700; color: #2C3E50; margin-top: 4px; }
.chart-placeholder {
  height: 300px; display: flex; flex-direction: column;
  align-items: center; justify-content: center;
  background: #f5f7fa; border-radius: 8px;
}
.chart-icon { font-size: 18px; color: #4A90E2; font-weight: 600; }
.chart-hint { font-size: 12px; color: #999; margin-top: 8px; }
</style>
