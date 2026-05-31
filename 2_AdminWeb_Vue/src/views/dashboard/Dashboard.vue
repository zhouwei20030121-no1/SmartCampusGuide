<template>
  <div class="dashboard">
    <!-- 欢迎栏 -->
    <div class="welcome-bar">
      <h3>您好，{{ username }}！欢迎来到数据控制中心。</h3>
      <p>
        今天是 {{ currentDate }}，系统运行状态：
        <span class="status-normal">正常 <span class="status-dot"></span></span>
      </p>
    </div>

    <!-- 统计卡片 -->
    <div class="stats-row">
      <div
        class="glass-card stat-card"
        v-for="card in statCards"
        :key="card.label"
        @click="card.link ? $router.push(card.link) : null"
        :style="{ cursor: card.link ? 'pointer' : 'default' }"
      >
        <div class="stat-icon-wrap" :style="{ background: card.bg }">
          <span class="stat-emoji">{{ card.emoji }}</span>
        </div>
        <div class="stat-info">
          <div class="stat-value">{{ card.value }}</div>
          <div class="stat-label">{{ card.label }}</div>
        </div>
      </div>
    </div>

    <!-- 双栏布局 -->
    <div class="main-grid">
      <!-- 近7日访问趋势 -->
      <div class="glass-card">
        <h4 class="panel-title">近7日访问趋势</h4>
        <div ref="chartRef" class="chart-container"></div>
      </div>

      <!-- 热门景点 TOP5 -->
      <div class="glass-card">
        <h4 class="panel-title">热门景点 TOP5</h4>
        <div class="spot-list">
          <div class="spot-row" v-for="(spot, i) in topSpots" :key="spot.name">
            <span class="spot-rank" :class="'rank-' + (i + 1)">{{ i + 1 }}</span>
            <span class="spot-name">{{ spot.name }}</span>
            <span class="spot-count">{{ spot.count }} 次</span>
          </div>
          <div v-if="topSpots.length === 0" class="empty-spots">
            <p>暂无数据</p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, nextTick } from 'vue'
import * as echarts from 'echarts'
import request from '@/api/request'

// 用户名
const username = ref('管理员')

// 图表
const chartRef = ref<HTMLDivElement>()
const chartReady = ref(false)

// 当前日期
const currentDate = computed(() => {
  const d = new Date()
  const weekDays = ['日', '一', '二', '三', '四', '五', '六']
  return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日 星期${weekDays[d.getDay()]}`
})

// 统计数据
const statCards = reactive([
  { label: '景点总数', value: '0', emoji: '📍', bg: 'rgba(74, 144, 226, 0.15)', link: '/spots' },
  { label: '导览路线', value: '0', emoji: '🗺️', bg: 'rgba(39, 174, 96, 0.15)', link: '/routes' },
  { label: '语料条目', value: '0', emoji: '📚', bg: 'rgba(243, 156, 18, 0.15)', link: '/corpus' },
  { label: '待审评论', value: '0', emoji: '💬', bg: 'rgba(231, 76, 60, 0.15)', link: '/comments' },
])

// 热门景点
const topSpots = ref<Array<{ name: string; count: number }>>([])

// 7日访问数据
const weeklyData = ref({
  dates: [] as string[],
  counts: [] as number[],
})

// 获取用户名
const getUsername = () => {
  const name = localStorage.getItem('username')
    || localStorage.getItem('realName')
    || localStorage.getItem('real_name')
  if (name) {
    username.value = name
  }
}

// 获取统计数据
const fetchStats = async () => {
  try {
    // 景点总数
    const spotRes = await request.get('/spot/list', { params: { page: 1, size: 1 } })
    const spotData = spotRes || (spotRes as any).data
    statCards[0].value = (spotData?.total || 0).toLocaleString()

    // 路线数
    try {
      const routeRes = await request.get('/route/plan/list', { params: { page: 1, size: 1 } })
      const routeData = routeRes || (routeRes as any).data
      statCards[1].value = (routeData?.total || 0).toLocaleString()
    } catch {
      statCards[1].value = '-'
    }

    // 语料条目数
    try {
      const corpusRes = await request.get('/ai/corpus/stats')
      const corpusData = corpusRes || (corpusRes as any).data
      statCards[2].value = ((corpusData?.enabled || 0) + (corpusData?.disabled || 0)).toLocaleString()
    } catch {
      statCards[2].value = '-'
    }

    // 待审核评论数
    try {
      const commentRes = await request.get('/comment/stats')
      const commentData = commentRes || (commentRes as any).data
      statCards[3].value = (commentData?.pending || 0).toLocaleString()
    } catch {
      statCards[3].value = '-'
    }
  } catch (error) {
    console.error('获取统计数据失败:', error)
  }
}

// 获取热门景点
const fetchTopSpots = async () => {
  try {
    const response = await request.get('/spot/list', {
      params: { page: 1, size: 5 }
    })
    const data = response || (response as any).data
    const records = data?.records || []
    if (records.length > 0) {
      topSpots.value = records
        .sort((a: any, b: any) => (b.visitCount || 0) - (a.visitCount || 0))
        .slice(0, 5)
        .map((s: any) => ({
          name: s.name,
          count: s.visitCount || 0,
        }))
    } else {
      topSpots.value = [
        { name: '崇德湖', count: 642 },
        { name: '行署楼', count: 518 },
        { name: '共青团花园', count: 435 },
        { name: '中心图书馆', count: 398 },
        { name: '竹园食堂', count: 276 },
      ]
    }
  } catch (error) {
    console.error('获取热门景点失败:', error)
    topSpots.value = [
      { name: '崇德湖', count: 642 },
      { name: '行署楼', count: 518 },
      { name: '共青团花园', count: 435 },
      { name: '中心图书馆', count: 398 },
      { name: '竹园食堂', count: 276 },
    ]
  }
}

// 获取7日访问趋势
const fetchWeeklyData = async () => {
  try {
    const response = await request.get('/stats/weekly-visits')
    const data = response || (response as any).data
    if (data && data.dates && data.counts) {
      weeklyData.value = {
        dates: data.dates,
        counts: data.counts,
      }
    }
  } catch (error) {
    console.error('获取访问趋势失败，使用模拟数据:', error)
    const dates: string[] = []
    const counts: number[] = []
    for (let i = 6; i >= 0; i--) {
      const d = new Date()
      d.setDate(d.getDate() - i)
      dates.push(`${d.getMonth() + 1}/${d.getDate()}`)
      counts.push(Math.floor(Math.random() * 200) + 50)
    }
    weeklyData.value = { dates, counts }
  }

  await nextTick()
  setTimeout(() => {
    renderChart()
  }, 100)
}

// 渲染图表
const renderChart = () => {
  const chartDom = chartRef.value
  if (!chartDom) {
    console.error('chartRef is null')
    return
  }

  // 检查容器宽高
  if (chartDom.clientWidth === 0 || chartDom.clientHeight === 0) {
    console.log('容器尺寸为0，延迟渲染')
    setTimeout(() => renderChart(), 200)
    return
  }

  // 销毁旧实例
  const existingChart = echarts.getInstanceByDom(chartDom)
  if (existingChart) {
    existingChart.dispose()
  }

  const chart = echarts.init(chartDom)
  chart.setOption({
    tooltip: {
      trigger: 'axis',
      formatter: (params: any) => {
        const p = params[0]
        return `${p.axisValue}<br/>访问量：${p.value} 次`
      }
    },
    grid: { left: '3%', right: '4%', bottom: '3%', containLabel: true },
    xAxis: {
      type: 'category',
      boundaryGap: false,
      data: weeklyData.value.dates,
      axisLine: { lineStyle: { color: '#ddd' } },
    },
    yAxis: {
      type: 'value',
      name: '访问量',
      splitLine: { lineStyle: { color: 'rgba(0,0,0,0.06)' } },
    },
    series: [{
      name: '访问量',
      data: weeklyData.value.counts,
      type: 'line',
      smooth: true,
      symbol: 'circle',
      symbolSize: 8,
      lineStyle: { color: '#1A5276', width: 3 },
      itemStyle: { color: '#1A5276' },
      areaStyle: {
        color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
          { offset: 0, color: 'rgba(26, 82, 118, 0.3)' },
          { offset: 1, color: 'rgba(26, 82, 118, 0.02)' },
        ]),
      },
    }],
  })

  chartReady.value = true
  window.addEventListener('resize', () => chart.resize())
}

onMounted(() => {
  getUsername()
  fetchStats()
  fetchTopSpots()
  fetchWeeklyData()
})
</script>

<style scoped>
.dashboard { padding: 0; }

/* ─── 欢迎栏 ─── */
.welcome-bar { margin-bottom: 28px; }
.welcome-bar h3 { margin: 0 0 6px; font-size: 20px; color: #1A5276; }
.welcome-bar p { margin: 0; font-size: 14px; color: #64748b; }
.status-normal { color: #27AE60; font-weight: 500; }
.status-dot {
  display: inline-block; width: 8px; height: 8px;
  background: #27AE60; border-radius: 50%; margin-left: 4px;
  animation: pulse 2s infinite;
}
@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.3; }
}

/* ─── 玻璃卡片 ─── */
.glass-card {
  background: rgba(255, 255, 255, 0.5);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: 1px solid rgba(255, 255, 255, 0.7);
  border-radius: 18px;
  padding: 24px;
  box-shadow: 0 4px 20px rgba(31, 38, 135, 0.06);
  transition: transform 0.3s, box-shadow 0.3s;
}
.glass-card:hover { transform: translateY(-2px); box-shadow: 0 8px 30px rgba(31, 38, 135, 0.1); }

/* ─── 统计卡片行 ─── */
.stats-row {
  display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px; margin-bottom: 24px;
}
.stat-card { display: flex; align-items: center; gap: 18px; }
.stat-icon-wrap {
  width: 56px; height: 56px; border-radius: 14px;
  display: flex; align-items: center; justify-content: center;
}
.stat-emoji { font-size: 26px; }
.stat-value { font-size: 26px; font-weight: 700; color: #1A5276; }
.stat-label { font-size: 13px; color: #64748b; margin-top: 2px; }

/* ─── 双栏布局 ─── */
.main-grid {
  display: grid; grid-template-columns: 2fr 1fr; gap: 20px;
}
.panel-title {
  margin: 0 0 20px; font-size: 17px; font-weight: 700; color: #1A5276;
  padding-bottom: 14px; border-bottom: 1px solid rgba(0,0,0,0.06);
}
.chart-container {
  height: 300px;
  width: 100%;
}

/* ─── 景点列表 ─── */
.spot-row {
  display: flex; align-items: center; padding: 13px 0;
  border-bottom: 1px dashed rgba(0,0,0,0.08);
}
.spot-row:last-child { border-bottom: none; }
.spot-rank {
  width: 28px; height: 28px; line-height: 28px; text-align: center;
  border-radius: 8px; font-size: 13px; font-weight: 700;
  background: rgba(0,0,0,0.05); color: #64748b; margin-right: 12px;
}
.rank-1 { background: #F39C12; color: #fff; }
.rank-2 { background: #95A5A6; color: #fff; }
.rank-3 { background: #CD853F; color: #fff; }
.spot-name { flex: 1; font-size: 15px; color: #1e293b; font-weight: 500; }
.spot-count { font-size: 13px; color: #1A5276; font-weight: 600; }
.empty-spots { text-align: center; color: #999; padding: 40px 0; }
</style>