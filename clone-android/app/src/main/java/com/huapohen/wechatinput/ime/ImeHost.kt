package com.huapohen.wechatinput.ime

interface ImeHost {
    fun commitText(text: String)
    fun setComposing(text: String)
    fun backspace()
    fun enter()
    fun space()
    fun launchPage(target: String, text: String)
    fun startVoice()
    fun stopVoice()
    fun cancelVoice()
    fun toast(message: String)
    fun finishComposing()
}
