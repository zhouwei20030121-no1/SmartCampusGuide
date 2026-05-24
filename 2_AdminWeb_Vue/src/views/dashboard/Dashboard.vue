<template>
  <div class="dashboard">
    <!-- 欢迎栏 -->
    <div class="welcome-bar">
      <h3>您好，管理员！欢迎来到数据控制中心。</h3>
      <p>今天是 {{ currentDate }}，系统运行状态：正常 <span class="status-dot"></span></p>
    </div>

    <!-- 统计卡片 -->
    <div class="stats-row">
      <div class="glass-card stat-card" v-for="card in statCards" :key="card.label">
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
      <div class="glass-card">
        <h4 class="panel-title">近7日访问趋势</h4>
        <div class="chart-placeholder">
          <p>ECharts 折线图区域</p>
          <p class="hint">TODO: 接入 ECharts 展示访问趋势</p>
        </div>
      </div>
      <div class="glass-card">
        <h4 class="panel-title">热门景点 TOP5</h4>
        <div class="spot-list">
          <div class="spot-row" v-for="(spot, i) in topSpots" :key="spot.name">
            <span class="spot-rank" :class="'rank-' + (i + 1)">{{ i + 1 }}</span>
            <span class="spot-name">{{ spot.name }}</span>
            <span class="spot-count">{{ spot.count }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const currentDate = computed(() => {
  const d = new Date()
  return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`
})

const statCards = [
  { label: '注册用户', value: '1,280', emoji: '👥', bg: 'rgba(74, 144, 226, 0.15)' },
  { label: '景点总数', value: '48', emoji: '📍', bg: 'rgba(39, 174, 96, 0.15)' },
  { label: '累计讲解', value: '3,520', emoji: '🎙️', bg: 'rgba(243, 156, 18, 0.15)' },
  { label: 'AI问答', value: '856', emoji: '💬', bg: 'rgba(231, 76, 60, 0.15)' },
]

const topSpots = [
  { name: '崇德湖', count: '642 次' },
  { name: '行署楼', count: '518 次' },
  { name: '共青团花园', count: '435 次' },
  { name: '中心图书馆', count: '398 次' },
  { name: '竹园食堂', count: '276 次' },
]
</script>

<style scoped>
.dashboard { padding: 0; }

/* ─── 欢迎栏 ─── */
.welcome-bar { margin-bottom: 28px; }
.welcome-bar h3 { margin: 0 0 6px; font-size: 20px; color: #1A5276; }
.welcome-bar p { margin: 0; font-size: 14px; color: #64748b; }
.status-dot {
  display: inline-block;
  width: 8px; height: 8px;
  background: #27AE60;
  border-radius: 50%;
  margin-left: 4px;
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
  transition: transform 0.3s;
}
.glass-card:hover {
  transform: translateY(-2px);
}

/* ─── 统计卡片行 ─── */
.stats-row {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 20px;
  margin-bottom: 24px;
}
.stat-card {
  display: flex;
  align-items: center;
  gap: 18px;
}
.stat-icon-wrap {
  width: 56px; height: 56px;
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.stat-emoji { font-size: 26px; }
.stat-value {
  font-size: 26px;
  font-weight: 700;
  color: #1A5276;
}
.stat-label {
  font-size: 13px;
  color: #64748b;
  margin-top: 2px;
}

/* ─── 双栏布局 ─── */
.main-grid {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 20px;
}
.panel-title {
  margin: 0 0 20px;
  font-size: 17px;
  font-weight: 700;
  color: #1A5276;
  padding-bottom: 14px;
  border-bottom: 1px solid rgba(0,0,0,0.06);
}
.chart-placeholder {
  height: 300px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: rgba(255,255,255,0.3);
  border-radius: 12px;
  color: #64748b;
  border: 2px dashed rgba(26, 82, 118, 0.15);
}
.chart-placeholder .hint { font-size: 13px; margin-top: 8px; opacity: 0.7; }

/* ─── 景点列表 ─── */
.spot-row {
  display: flex;
  align-items: center;
  padding: 13px 0;
  border-bottom: 1px dashed rgba(0,0,0,0.08);
}
.spot-row:last-child { border-bottom: none; }
.spot-rank {
  width: 28px; height: 28px;
  line-height: 28px;
  text-align: center;
  border-radius: 8px;
  font-size: 13px;
  font-weight: 700;
  background: rgba(0,0,0,0.05);
  color: #64748b;
  margin-right: 12px;
}
.rank-1 { background: #F39C12; color: #fff; }
.rank-2 { background: #95A5A6; color: #fff; }
.rank-3 { background: #CD853F; color: #fff; }
.spot-name { flex: 1; font-size: 15px; color: #1e293b; font-weight: 500; }
.spot-count { font-size: 13px; color: #1A5276; font-weight: 600; }
</style>
