<template>
  <view class="container">
    <image class="bg-image" src="/static/images/login_bg.jpg" mode="aspectFill"></image>

    <view class="card-wrapper">
      <glass-card>
        <view class="header">
          <text class="title">西大智能导览</text>
        </view>

        <view class="input-box">
          <input class="glass-input" type="text" placeholder="校园网账号/手机号" placeholder-class="placeholder-style" v-model="account" />
        </view>

        <view class="input-box">
          <input class="glass-input" type="password" placeholder="密码" placeholder-class="placeholder-style" v-model="password" />
        </view>

        <button class="primary-btn" @click="handleLogin">登 录</button>

        <view class="footer">
          <text class="link-text">忘记密码?</text>
          <text class="link-text active" @click="goToRegister">没有账号? 去注册</text>
        </view>
      </glass-card>
    </view>
  </view>
</template>

<script setup>
import { ref } from 'vue';

const account = ref('');
const password = ref('');

const handleLogin = () => {
  if(!account.value || !password.value) {
    return uni.showToast({ title: '请输入账号和密码', icon: 'none' });
  }
  // TODO: 对接 Java 后端接口
  console.log('登录账号:', account.value);
};

const goToRegister = () => {
  uni.navigateTo({
    url: '/pages/user_map/register'
  });
};
</script>

<style lang="scss" scoped>
.container {
  width: 100vw;
  height: 100vh;
  position: relative;
  display: flex;
  justify-content: center;
  align-items: center;
}
.bg-image {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  z-index: -1;
}
.card-wrapper {
  width: 85%;
}
.header {
  text-align: center;
  margin-bottom: 60rpx;
}
.title {
  font-size: 48rpx;
  font-weight: bold;
  color: $campus-primary;
}
.input-box {
  margin-bottom: 30rpx;
}
.glass-input {
  width: 100%;
  height: 90rpx;
  background: rgba(255, 255, 255, 0.6);
  border-radius: 20rpx;
  padding: 0 30rpx;
  box-sizing: border-box;
  font-size: 28rpx;
  color: $campus-text-main;
}
/* 必须使用 /deep/ 或在 placeholder-class 中定义样式 */
:deep(.placeholder-style) {
  color: $campus-text-sub;
}
.primary-btn {
  margin-top: 50rpx;
  background-color: $campus-primary;
  color: #FFFFFF;
  border-radius: 20rpx;
  height: 90rpx;
  line-height: 90rpx;
  font-size: 32rpx;
}
.primary-btn::after { border: none; } /* 去掉自带边框 */

.footer {
  display: flex;
  justify-content: space-between;
  margin-top: 40rpx;
}
.link-text {
  font-size: 26rpx;
  color: $campus-text-sub;
}
.active {
  color: $campus-primary;
  font-weight: bold;
}
</style>
