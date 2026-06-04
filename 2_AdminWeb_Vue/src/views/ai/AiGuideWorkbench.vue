<template>
  <div class="ai-workbench">
    <section class="panel">
      <div class="panel-head">
        <div>
          <h2>AI动态讲解工作台</h2>
          <p>RAG 检索、用户风格、多语种与音色参数联调</p>
        </div>
        <div class="quick-links">
          <router-link to="/corpus">语料库</router-link>
          <router-link to="/comments">评论审核</router-link>
        </div>
      </div>

      <div class="grid">
        <label>
          景点名称
          <input v-model="form.spotName" placeholder="例如：中心图书馆" />
        </label>
        <label>
          用户身份
          <select v-model="form.persona">
            <option value="新生">新生</option>
            <option value="校友">校友</option>
            <option value="游客">游客</option>
          </select>
        </label>
        <label>
          讲解语言
          <select v-model="form.language">
            <option value="zh">中文</option>
            <option value="en">English</option>
          </select>
        </label>
        <label>
          播报音色
          <select v-model="form.voice">
            <option value="gentle_guide">温柔导游</option>
            <option value="young_female">青年女声</option>
            <option value="young_male">青年男声</option>
          </select>
        </label>
        <label>
          Top K
          <input v-model.number="form.topK" type="number" min="1" max="10" />
        </label>
        <label>
          环境状态
          <input v-model="form.environment" placeholder="雨天、迎新季、毕业季..." />
        </label>
      </div>

      <div class="prompt-area">
        <label>
          Prompt 编排备注
          <textarea v-model="form.promptNote" rows="4" placeholder="记录当前模板目标、风格约束或事实校准要求"></textarea>
        </label>
      </div>

      <div class="actions">
        <button :disabled="loadingGuide" @click="generateGuide">
          {{ loadingGuide ? '生成中...' : '生成讲解词' }}
        </button>
        <button class="secondary" :disabled="loadingStory" @click="generateStory">
          {{ loadingStory ? '生成中...' : '生成校园故事' }}
        </button>
      </div>
    </section>

    <section class="results">
      <article>
        <header>
          <span>讲解词</span>
          <small>{{ guideMeta }}</small>
        </header>
        <pre>{{ guideText || '暂无内容' }}</pre>
      </article>
      <article>
        <header>
          <span>故事演进</span>
          <small>基于评论、时间节点与景点资料</small>
        </header>
        <textarea v-model="commentDraft" rows="4" placeholder="输入几条评论或校园回忆，每行一条"></textarea>
        <pre>{{ storyText || '暂无内容' }}</pre>
      </article>
      <article>
        <header>
          <span>Grounding</span>
          <small>检索召回与事实校准</small>
        </header>
        <ul>
          <li v-for="source in sources" :key="source.id || source.title">
            <strong>{{ source.title || source.question || '资料片段' }}</strong>
            <p>{{ source.answer || source.content || source.source || '暂无摘要' }}</p>
          </li>
        </ul>
      </article>
    </section>
  </div>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from 'vue'
import request from '@/api/request'

const form = reactive({
  spotName: '中心图书馆',
  persona: '新生',
  language: 'zh',
  voice: 'gentle_guide',
  topK: 5,
  environment: '移动端智能讲解场景',
  promptNote: '优先使用检索资料，语气自然，适合语音播报。',
})

const loadingGuide = ref(false)
const loadingStory = ref(false)
const guideText = ref('')
const storyText = ref('')
const sources = ref<any[]>([])
const commentDraft = ref('第一次来这里时感觉校园特别大。\n这里适合自习，也适合和同学约着见面。')

const guideMeta = computed(() => `${form.persona} / ${form.language} / ${voiceName(form.voice)}`)

const generateGuide = async () => {
  loadingGuide.value = true
  try {
    const res: any = await request.post('/ai/guide/dynamic', {
      spotName: form.spotName,
      persona: form.persona,
      language: form.language,
      voice: form.voice,
      topK: form.topK,
      environment: {
        adminNote: form.promptNote,
        scene: form.environment,
      },
    })
    const data = res?.data || res || {}
    guideText.value = data.text || ''
    sources.value = data.sources || []
  } finally {
    loadingGuide.value = false
  }
}

const generateStory = async () => {
  loadingStory.value = true
  try {
    const comments = commentDraft.value.split('\n').map(item => item.trim()).filter(Boolean)
    const res: any = await request.post('/ai/story/generate', {
      spotName: form.spotName,
      persona: form.persona,
      language: form.language,
      comments,
      timeContext: form.environment,
    })
    const data = res?.data || res || {}
    storyText.value = data.story || ''
    if (data.sources) sources.value = data.sources
  } finally {
    loadingStory.value = false
  }
}

const voiceName = (voice: string) => {
  if (voice === 'young_male') return '青年男声'
  if (voice === 'young_female') return '青年女声'
  return '温柔导游'
}
</script>

<style scoped>
.ai-workbench {
  display: grid;
  gap: 18px;
  color: #1f2937;
}

.panel,
.results article {
  background: rgba(255, 255, 255, 0.82);
  border: 1px solid rgba(255, 255, 255, 0.8);
  border-radius: 8px;
  box-shadow: 0 12px 30px rgba(15, 23, 42, 0.08);
}

.panel {
  padding: 22px;
}

.panel-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 18px;
}

h2 {
  margin: 0;
  font-size: 22px;
  color: #123b5d;
}

p {
  margin: 6px 0 0;
  color: #64748b;
}

.quick-links {
  display: flex;
  gap: 8px;
}

.quick-links a,
button {
  border: 0;
  border-radius: 6px;
  background: #1a5276;
  color: #fff;
  cursor: pointer;
  font-weight: 600;
  padding: 9px 14px;
  text-decoration: none;
}

.quick-links a {
  background: rgba(26, 82, 118, 0.1);
  color: #1a5276;
}

.grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(180px, 1fr));
  gap: 14px;
}

label {
  display: grid;
  gap: 7px;
  font-size: 13px;
  font-weight: 700;
  color: #334155;
}

input,
select,
textarea {
  width: 100%;
  box-sizing: border-box;
  border: 1px solid #d7e3ec;
  border-radius: 6px;
  color: #1f2937;
  font: inherit;
  outline: none;
  padding: 10px 11px;
}

textarea {
  resize: vertical;
}

.prompt-area {
  margin-top: 14px;
}

.actions {
  display: flex;
  gap: 10px;
  margin-top: 16px;
}

button.secondary {
  background: #0f766e;
}

button:disabled {
  cursor: wait;
  opacity: 0.65;
}

.results {
  display: grid;
  grid-template-columns: minmax(0, 1.2fr) minmax(0, 1fr) minmax(260px, 0.9fr);
  gap: 18px;
}

.results article {
  min-height: 260px;
  padding: 16px;
}

header {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 10px;
}

header span {
  color: #123b5d;
  font-size: 16px;
  font-weight: 800;
}

header small {
  color: #64748b;
}

pre {
  white-space: pre-wrap;
  word-break: break-word;
  line-height: 1.7;
  margin: 0;
  color: #334155;
  font-family: inherit;
}

ul {
  display: grid;
  gap: 10px;
  margin: 0;
  padding: 0;
  list-style: none;
}

li {
  border-left: 3px solid #1a5276;
  padding-left: 10px;
}

li strong {
  color: #123b5d;
}

@media (max-width: 1180px) {
  .grid,
  .results {
    grid-template-columns: 1fr;
  }
}
</style>
