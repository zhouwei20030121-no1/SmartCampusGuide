<template>
  <view class="container">
    <image class="bg-image" src="/static/images/login_bg.jpg" mode="aspectFill"></image>
    <view class="back-btn" @click="goBack">
       <text class="back-icon">← 返回</text>
    </view>

    <view class="card-wrapper">
      <glass-card padding="60rpx 40rpx">
        <view class="header">
          <text class="title">注册新账号</text>
        </view>

        <view class="input-box">
          <input class="glass-input" type="text" placeholder="请输入学号或手机号" placeholder-class="placeholder-style" v-model="account" />
        </view>
        <view class="input-box">
          <input class="glass-input" type="password" placeholder="设置密码" placeholder-class="placeholder-style" v-model="password" />
        </view>
        <view class="input-box">
          <input class="glass-input" type="password" placeholder="确认密码" placeholder-class="placeholder-style" v-model="confirmPwd" />
        </view>

        <button class="primary-btn" @click="handleRegister">立即注册</button>
      </glass-card>
    </view>
  </view>
</template>

<script setup>
import { ref } from 'vue';

const account = ref('');
const password = ref('');
const confirmPwd = ref('');

const goBack = () => {
  uni.navigateBack();
};

const handleRegister = () => {
  console.log('发起注册');
};
</script>

<style lang="scss" scoped>
/* 样式与 login.vue 几乎一致，加上返回按钮样式即可 */
.container { width: 100vw; height: 100vh; position: relative; display: flex; justify-content: center; align-items: center; }
.bg-image { position: absolute; top: 0; left: 0; width: 100%; height: 100%; z-index: -1; }
.back-btn { position: absolute; top: 100rpx; left: 40rpx; z-index: 10; padding: 10rpx; }
.back-icon { font-size: 32rpx; color: $campus-primary; font-weight: bold; }
.card-wrapper { width: 85%; }
.header { text-align: center; margin-bottom: 60rpx; }
.title { font-size: 48rpx; font-weight: bold; color: $campus-primary; }
.input-box { margin-bottom: 30rpx; }
.glass-input { width: 100%; height: 90rpx; background: rgba(255,255,255,0.6); border-radius: 20rpx; padding: 0 30rpx; box-sizing: border-box; font-size: 28rpx; color: $campus-text-main; }
:deep(.placeholder-style) { color: $campus-text-sub; }
.primary-btn { margin-top: 50rpx; background-color: $campus-primary; color: #FFFFFF; border-radius: 20rpx; height: 90rpx; line-height: 90rpx; font-size: 32rpx; }
.primary-btn::after { border: none; }
</style>
