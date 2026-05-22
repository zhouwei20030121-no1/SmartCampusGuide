<template>
  <div class="dashboard">
    <h2>数据大屏</h2>
    <el-row :gutter="20">
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-value">1,286</div>
          <div class="stat-label">累计用户</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-value">48</div>
          <div class="stat-label">景点数量</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-value">3,520</div>
          <div class="stat-label">今日导览次数</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-value">256</div>
          <div class="stat-label">待审评论</div>
        </el-card>
      </el-col>
    </el-row>
    <el-card style="margin-top:20px">
      <template #header>近7天导览趋势</template>
      <div class="chart-placeholder" ref="chartRef"></div>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import * as echarts from 'echarts'

const chartRef = ref<HTMLElement>()

onMounted(() => {
  if (!chartRef.value) return
  const chart = echarts.init(chartRef.value)
  chart.setOption({
    tooltip: { trigger: 'axis' },
    xAxis: { type: 'category', data: ['周一','周二','周三','周四','周五','周六','周日'] },
    yAxis: { type: 'value' },
    series: [{
      data: [420, 480, 550, 520, 610, 580, 350],
      type: 'line',
      smooth: true,
      color: '#4A90E2',
      areaStyle: { color: 'rgba(74,144,226,0.15)' },
    }],
  })
})
</script>

<style scoped>
.stat-card { text-align: center; }
.stat-value { font-size: 28px; font-weight: bold; color: #4A90E2; }
.stat-label { font-size: 14px; color: #999; margin-top: 8px; }
.chart-placeholder { width: 100%; height: 300px; }
</style>
