<template>
  <view class="glass-card" :style="{ padding: padding }">
    <slot></slot>
  </view>
</template>

<script setup>
import { defineProps } from 'vue';

const props = defineProps({
  padding: {
    type: String,
    default: '60rpx 40rpx'
  }
});
</script>

<style scoped>
.glass-card {
  width: 100%;
  box-sizing: border-box;
  border-radius: 32rpx;

  /* CSS3 毛玻璃核心代码 */
  background: rgba(255, 255, 255, 0.4);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);

  /* 玻璃的高光白边与立体阴影 */
  border: 2rpx solid rgba(255, 255, 255, 0.6);
  box-shadow: 0 16rpx 32rpx rgba(0, 0, 0, 0.1);
}
</style>
