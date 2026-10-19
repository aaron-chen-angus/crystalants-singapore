class_name CrystalLocalization
extends RefCounted

var locale := "en"
var strings := {
    "en": {"title":"CRYSTAL ANTS", "subtitle":"SINGAPORE QUEST", "tagline":"Plan the colour. Guide the colony.", "adventure":"Adventure", "time_attack":"Time Attack", "strategic":"Strategic Challenge", "daily":"Daily Challenge", "research":"Research Mode", "choose_landmark":"Choose a landmark to begin", "moves":"MOVES", "optimal":"CERTIFIED OPTIMAL", "efficiency":"EFFICIENCY", "progress":"CRYSTALS", "select_colour":"Select a colour to expand the colony", "undo":"Undo", "restart":"Restart", "pause":"Pause", "resume":"Resume", "hint":"Hint", "how_to_play":"How to play", "back":"Back to map", "next":"Next landmark", "complete":"Landmark restored", "complete_copy":"Every crystal is now part of your connected colony.", "certified":"Certified solution", "uncertified":"Exact optimum unavailable for this board", "practice":"Practice mode", "high_contrast":"High contrast", "reduced_motion":"Reduced motion", "large_text":"Large text", "language":"中文", "pause_title":"PAUSED", "pause_copy":"Take a breath. Your active time is not counting.", "tutorial_title":"THE COLONY RULE", "tutorial_copy":"Choose a colour. Matching crystal regions touching your colony orthogonally are consumed as one connected expansion. Diagonals never count.", "daily_note":"Today's shared seed", "research_note":"Standardised local session", "timer":"TIME", "budget":"BUDGET", "best":"BEST"},
    "zh": {"title":"水晶蚂蚁", "subtitle":"新加坡探索", "tagline":"规划颜色，引导蚁群。", "adventure":"冒险模式", "time_attack":"限时挑战", "strategic":"策略挑战", "daily":"每日挑战", "research":"研究模式", "choose_landmark":"选择一个地标开始", "moves":"步数", "optimal":"认证最优", "efficiency":"效率", "progress":"水晶", "select_colour":"选择颜色扩展蚁群", "undo":"撤销", "restart":"重新开始", "pause":"暂停", "resume":"继续", "hint":"提示", "how_to_play":"玩法说明", "back":"返回地图", "next":"下一个地标", "complete":"地标已修复", "complete_copy":"所有水晶都已成为你相连蚁群的一部分。", "certified":"认证解法", "uncertified":"此棋盘无法提供精确最优解", "practice":"练习模式", "high_contrast":"高对比度", "reduced_motion":"减少动画", "large_text":"大字体", "language":"EN", "pause_title":"已暂停", "pause_copy":"休息一下，活动时间不会继续计时。", "tutorial_title":"蚁群规则", "tutorial_copy":"选择一种颜色。与蚁群正交相邻的同色水晶区域会被一次性吸收。对角线不算相邻。", "daily_note":"今日共享种子", "research_note":"标准化本地会话", "timer":"时间", "budget":"步数上限", "best":"最佳"}
}

func t(key: String) -> String:
    if strings.has(locale) and strings[locale].has(key):
        return strings[locale][key]
    return strings.en.get(key, key)

func toggle() -> void:
    locale = "zh" if locale == "en" else "en"
