import axios from 'axios'
import { ElMessage } from 'element-plus'

const request = axios.create({
  baseURL: '/api',
  timeout: 15000,
})

request.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => Promise.reject(error),
)

request.interceptors.response.use(
  (response) => {
    const res = response.data
    
    // 如果直接返回数据（没有code字段），直接返回
    if (res && res.code === undefined) {
      return res
    }
    
    // 处理标准的 { code, message, data } 格式
    if (res.code === 200 || res.code === 0) {
      return res.data !== undefined ? res.data : res
    }
    
    ElMessage.error(res.message || res.msg || '请求失败')
    return Promise.reject(new Error(res.message || res.msg || '请求失败'))
  },
  (error) => {
    const message = error.response?.data?.message || error.message || '网络异常'
    ElMessage.error(message)
    return Promise.reject(error)
  },
)

export default request
