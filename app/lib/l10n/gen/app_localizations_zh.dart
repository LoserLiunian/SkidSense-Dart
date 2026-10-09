// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class L10nZh extends L10n {
  L10nZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'SkidSense';

  @override
  String get ok => '好';

  @override
  String get cancel => '取消';

  @override
  String get retry => '重试';

  @override
  String get back => '返回';

  @override
  String get close => '关闭';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get rename => '重命名';

  @override
  String get refresh => '刷新';

  @override
  String get copy => '复制';

  @override
  String get copied => '已复制';

  @override
  String get done => '完成';

  @override
  String get edit => '编辑';

  @override
  String get preview => '预览';

  @override
  String get reload => '重新加载';

  @override
  String get more => '更多';

  @override
  String get search => '搜索';

  @override
  String get clear => '清除';

  @override
  String get create => '创建';

  @override
  String get continueAction => '继续';

  @override
  String get dismiss => '关闭';

  @override
  String get none => '—';

  @override
  String get loginTitle => '登录';

  @override
  String get loginSubtitle => '用与电脑端 SkidSense 相同的账号登录——两端靠它找到彼此。';

  @override
  String get serverAddress => '服务器';

  @override
  String serverAddressUsed(String address) {
    return '将使用 $address';
  }

  @override
  String get serverAddressInvalid => '请输入服务器地址，例如 https://example.com';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get showPassword => '显示密码';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get signIn => '登录';

  @override
  String get testConnection => '测试连接';

  @override
  String serverReachable(String name) {
    return '服务器可用：$name';
  }

  @override
  String get captchaTitle => '人机验证';

  @override
  String get captchaPassed => '已通过验证';

  @override
  String get captchaRedo => '重新验证';

  @override
  String captchaFailed(String code) {
    return '验证失败（$code），请重试。';
  }

  @override
  String get captchaExpired => '验证已过期，请重试。';

  @override
  String get captchaOnSignIn => '登录时会弹出人机验证。';

  @override
  String get captchaLoading => '正在加载人机验证…';

  @override
  String get captchaLoadFailed => '人机验证加载失败';

  @override
  String get captchaLoadFailedHint => '请检查网络连接，然后重试。';

  @override
  String get passwordLoginDisabled => '这个服务器关闭了密码登录。';

  @override
  String get pairingAfterLogin => '登录与配对是两步：先在这里登录，再扫描电脑上的二维码。';

  @override
  String get twoFactorTitle => '两步验证';

  @override
  String get twoFactorHint => '输入验证器里的 6 位验证码，或一枚备用码。';

  @override
  String get twoFactorRequired => '这个账号需要二次验证。';

  @override
  String twoFactorMethods(String methods) {
    return '可用方式：$methods';
  }

  @override
  String get verificationCode => '验证码';

  @override
  String get verify => '验证';

  @override
  String get twoFactorPasskeyOnly =>
      '这个账号的二次验证是通行密钥（Passkey），App 暂不支持。请先在网页端开启两步验证并绑定验证器 App，再回到这里用它的验证码登录。';

  @override
  String get hostsTitle => '我的电脑';

  @override
  String signedInAs(String user, String server) {
    return '$user · $server';
  }

  @override
  String get pairComputer => '配对电脑';

  @override
  String get pairedSection => '已配对';

  @override
  String get pairedSectionHint => '可以直接连接';

  @override
  String get otherHostsSection => '这个账号的其他电脑';

  @override
  String get otherHostsHint => '还没有和这台手机配对';

  @override
  String get presenceOnline => '在线';

  @override
  String get presenceRelayOffline => '中继离线';

  @override
  String get presenceOffline => '离线';

  @override
  String get presenceRelayOfflineHint => '没有连到中继——在局域网里仍可能连得上。';

  @override
  String get fingerprint => '指纹';

  @override
  String get lanAddresses => '局域网';

  @override
  String get connect => '连接';

  @override
  String get forget => '忘记';

  @override
  String forgetTitle(String name) {
    return '忘记「$name」？';
  }

  @override
  String get forgetBody => '会同时在服务器上撤销这台手机：电脑立即断开它，也不再为它加密历史。之后要重新扫码才能再连。';

  @override
  String get forgetAction => '忘记并撤销';

  @override
  String get noComputersTitle => '还没有电脑';

  @override
  String get noComputersBody => '在电脑端 SkidSense 里打开「远程控制」并生成配对二维码，再回到这里扫描。';

  @override
  String get hostNeedsQr => '在它上面生成二维码即可配对';

  @override
  String get loadingHosts => '正在读取电脑列表…';

  @override
  String get settings => '设置';

  @override
  String get pairingTitle => '配对电脑';

  @override
  String get pairingIntro =>
      '在电脑端 SkidSense 打开「远程控制」，扫描窗口里的二维码。二维码只能用一次，10 分钟内有效。';

  @override
  String get scanQr => '扫描二维码';

  @override
  String get pasteLinkSection => '或者粘贴配对链接';

  @override
  String get pasteLinkLabel => 'skidsense://pair/1?d=…';

  @override
  String get readLink => '读取链接';

  @override
  String get confirmComputer => '是这台电脑吗？';

  @override
  String get machineName => '名称';

  @override
  String get backend => '服务器';

  @override
  String get fingerprintCheck => '请与电脑屏幕上显示的指纹逐组核对。不一致就说明这个二维码不是你正在用的那台电脑。';

  @override
  String get confirmPair => '配对';

  @override
  String get pairStepRegistering => '正在登记这台手机…';

  @override
  String get pairStepAlreadyRegistered => '这台手机已经登记过，正在重新连接…';

  @override
  String get pairStepHandshaking => '正在与电脑握手…';

  @override
  String get pairStepRepairing => '电脑上没有这台手机的记录，正在重新配对…';

  @override
  String get pairStepFinishing => '配对完成，正在读取这台手机被授予的权限…';

  @override
  String pairStepTrying(String route) {
    return '正在尝试$route…';
  }

  @override
  String get cameraUnavailable => '相机不可用。请改为粘贴配对链接。';

  @override
  String get scannerPrompt => '把电脑上的二维码放进取景框';

  @override
  String get scannerTorch => '手电筒';

  @override
  String get notAPairingCode => '这不是 SkidSense 的配对二维码。';

  @override
  String get tabSessions => '会话';

  @override
  String get tabFiles => '文件';

  @override
  String get tabGit => 'Git';

  @override
  String get tabHistory => '历史';

  @override
  String routeLan(String address) {
    return '局域网 $address';
  }

  @override
  String get routeRelay => '中继';

  @override
  String statusConnected(String route) {
    return '已连接 · $route';
  }

  @override
  String statusConnectedLimited(String route, int rate) {
    return '已连接 · $route（限速 $rate KB/s）';
  }

  @override
  String statusConnecting(String route) {
    return '正在连接 · $route';
  }

  @override
  String get statusAuthorizing => '正在连接 · 获取授权';

  @override
  String statusWaiting(String error, int seconds) {
    return '$error · $seconds 秒后重试';
  }

  @override
  String statusFailed(String error) {
    return '连接失败：$error';
  }

  @override
  String get statusIdle => '未连接';

  @override
  String get offlineTitle => '还没有连上电脑';

  @override
  String get offlineBody => '确认电脑上的 SkidSense 正在运行，且这台手机与它配对过。局域网不可用时会自动走中继。';

  @override
  String get backToComputers => '电脑';

  @override
  String get searchSessions => '搜索会话';

  @override
  String get noSessionsTitle => '还没有会话';

  @override
  String get noSessionsBody => '在电脑上开始一个，或者在这里新建。';

  @override
  String get noSessionsNoPrompt => '这台手机不能新建会话。';

  @override
  String noSearchResults(String query) {
    return '没有与「$query」匹配的会话';
  }

  @override
  String get newSession => '新建会话';

  @override
  String get workspace => '工作区';

  @override
  String get agent => '代理';

  @override
  String get titleOptional => '标题（可留空）';

  @override
  String get renameSession => '重命名会话';

  @override
  String get sessionTitle => '标题';

  @override
  String deleteSessionTitle(String title) {
    return '删除「$title」？';
  }

  @override
  String get deleteSessionBody => '会话和它的记录会在电脑上删除。';

  @override
  String backgroundJobs(int count) {
    return '$count 个后台任务';
  }

  @override
  String get loadingSessions => '正在读取会话…';

  @override
  String get runStateRunning => '运行中';

  @override
  String get runStateAwaiting => '等你回应';

  @override
  String get runStateStarting => '启动中';

  @override
  String get runStateIdle => '空闲';

  @override
  String get runStateDone => '已完成';

  @override
  String get runStateError => '失败';

  @override
  String get runStateAborted => '已停止';

  @override
  String get runStatePending => '等待中';

  @override
  String get runStateCancelled => '已取消';

  @override
  String updatedAgo(String ago) {
    return '$ago更新';
  }

  @override
  String get openingSession => '正在打开会话…';

  @override
  String get sessionNotFound => '电脑上没有这个会话。';

  @override
  String get openTerminal => '终端';

  @override
  String get openFiles => '文件';

  @override
  String get openGit => 'Git';

  @override
  String get approvalPermission => '需要你的许可';

  @override
  String get approvalQuestion => '代理在提问';

  @override
  String get approvalInput => '代理在等输入';

  @override
  String get approvalOther => '代理需要回应';

  @override
  String get approvalFreeText => '可自由回答';

  @override
  String approvalCwd(String cwd) {
    return '工作目录：$cwd';
  }

  @override
  String approvalScopes(String scopes) {
    return '请求的权限：$scopes';
  }

  @override
  String get approvalNoPermission => '这台手机没有审批权限。请在电脑上回应，或换一台有权限的设备。';

  @override
  String approvalAnsweredElsewhere(String device) {
    return '已在「$device」上回应';
  }

  @override
  String get allow => '允许';

  @override
  String get deny => '拒绝';

  @override
  String get sendAnswer => '发送回答';

  @override
  String get skip => '跳过';

  @override
  String get cancelTurn => '取消回合';

  @override
  String get answerPlaceholder => '你的回答';

  @override
  String get toolInput => '输入';

  @override
  String get toolResult => '结果';

  @override
  String toolTruncated(String label, String size) {
    return '$label已截断（原始 $size）';
  }

  @override
  String get messageHint => '说点什么';

  @override
  String get steerHint => '追加到正在进行的回合';

  @override
  String get send => '发送';

  @override
  String get steer => '插话';

  @override
  String get stop => '停止';

  @override
  String get composerOptions => '选项';

  @override
  String get attach => '添加附件';

  @override
  String get attachmentsNote => '附件会随下一条消息发送；离开这个会话就会丢弃。';

  @override
  String get remove => '移除';

  @override
  String get noPromptPermission => '这台手机没有发消息的权限。';

  @override
  String get options => '发送选项';

  @override
  String get model => '模型';

  @override
  String get modelDefault => '默认';

  @override
  String modelAccount(String account) {
    return '模型（$account）';
  }

  @override
  String get noModels => '没有可选的模型列表';

  @override
  String get effort => '思考强度';

  @override
  String get effortMinimal => '最低';

  @override
  String get effortLow => '低';

  @override
  String get effortMedium => '中';

  @override
  String get effortHigh => '高';

  @override
  String get effortXhigh => '很高';

  @override
  String get effortMax => '最高';

  @override
  String get effortUltra => '极致';

  @override
  String get approvalMode => '审批方式';

  @override
  String get approvalModeLocked => '审批方式（这台手机没有审批权限，只能用默认）';

  @override
  String get approvalDefault => '每次询问';

  @override
  String get approvalAcceptEdits => '自动接受编辑';

  @override
  String get approvalPlan => '仅计划';

  @override
  String get approvalDontAsk => '不再询问';

  @override
  String get approvalBypass => '绕过全部权限';

  @override
  String get thinking => '思考过程';

  @override
  String get plan => '计划';

  @override
  String get backgroundTasks => '后台任务';

  @override
  String usageContext(String tokens) {
    return '上下文 $tokens';
  }

  @override
  String usageOutput(String tokens) {
    return '输出 $tokens';
  }

  @override
  String steered(String text) {
    return '插话：$text';
  }

  @override
  String get compactedAuto => '上下文已自动压缩';

  @override
  String get compactedManual => '上下文已压缩';

  @override
  String get subAgent => '子代理';

  @override
  String get subAgentTask => '任务';

  @override
  String get subAgentLatest => '最近发言';

  @override
  String get subAgentReport => '结果';

  @override
  String get workflow => '工作流';

  @override
  String toolCalls(int count) {
    return '$count 次工具调用';
  }

  @override
  String promptRefused(String reason) {
    return '电脑没有接受这条消息：$reason';
  }

  @override
  String get promptRefusedPlain => '电脑没有接受这条消息。';

  @override
  String get promptUncertain => '没有收到回应——回合可能已经开始。请先查看会话记录，再决定是否重发。';

  @override
  String get promptUncertainDropped =>
      '没有收到回应——回合可能已经开始。请先查看会话记录，再决定是否重发；附件已移除，需要重新添加。';

  @override
  String uploadIncomplete(String name) {
    return '「$name」还没传完。';
  }

  @override
  String uploading(String name) {
    return '正在上传 $name';
  }

  @override
  String get jumpToLatest => '最新';

  @override
  String get you => '你';

  @override
  String get filesTitle => '文件';

  @override
  String get searchContent => '搜索文件内容';

  @override
  String get regex => '正则';

  @override
  String get searching => '正在搜索…';

  @override
  String searchSummary(int matches, int files) {
    return '$files 个文件中 $matches 处匹配';
  }

  @override
  String get searchCancelled => '搜索已停止';

  @override
  String get searchInterrupted => '连接中断，搜索已停止，请重新搜索。';

  @override
  String moreMatches(int count) {
    return '还有 $count 处';
  }

  @override
  String get dirTruncated => '这个目录的项目太多，只显示了一部分。';

  @override
  String get emptyDir => '这里是空的';

  @override
  String get showIgnored => '显示被忽略的文件';

  @override
  String get binaryFile => '这是二进制文件，只能预览。';

  @override
  String get tooLargeFile => '文件太大，无法在这里打开。';

  @override
  String fileLines(int count, String size) {
    return '$count 行 · $size';
  }

  @override
  String get saved => '已保存';

  @override
  String get saveConflict => '文件在别处被改过，为避免覆盖，保存被拒绝。请重新加载后再改。';

  @override
  String get unsavedChanges => '放弃你的修改？';

  @override
  String get discard => '放弃';

  @override
  String get newFile => '新建文件';

  @override
  String get newFolder => '新建文件夹';

  @override
  String get name => '名称';

  @override
  String deleteItemTitle(String name) {
    return '删除「$name」？';
  }

  @override
  String get deleteItemBody => '它会在电脑上被删除。';

  @override
  String get noWorkspace => '没有工作区';

  @override
  String get chooseWorkspace => '工作区';

  @override
  String get root => '根目录';

  @override
  String get gitTitle => 'Git';

  @override
  String get notARepo => '这个工作区还不是 Git 仓库。';

  @override
  String get initRepo => '在这里初始化仓库';

  @override
  String get branch => '分支';

  @override
  String detached(String sha) {
    return '游离于 $sha';
  }

  @override
  String upstream(String name) {
    return '上游 $name';
  }

  @override
  String aheadBehind(int ahead, int behind) {
    return '↑$ahead ↓$behind';
  }

  @override
  String get branches => '分支';

  @override
  String get fetch => '获取';

  @override
  String get pull => '拉取';

  @override
  String get push => '推送';

  @override
  String get switchBranch => '切换';

  @override
  String get currentBranch => '当前';

  @override
  String get remoteBranch => '远程';

  @override
  String get changes => '改动';

  @override
  String get staged => '已暂存';

  @override
  String get unstaged => '未暂存';

  @override
  String get noChanges => '没有可提交的改动';

  @override
  String get stage => '暂存';

  @override
  String get unstage => '取消暂存';

  @override
  String get stageAll => '全部暂存';

  @override
  String get discardChanges => '丢弃改动';

  @override
  String discardTitle(String path) {
    return '丢弃对 $path 的改动？';
  }

  @override
  String get discardBody => '这些改动会在电脑上丢失。';

  @override
  String get commit => '提交';

  @override
  String get commitMessage => '提交说明';

  @override
  String get commitStaged => '提交已暂存的改动';

  @override
  String get committed => '已提交';

  @override
  String renamedFrom(String path) {
    return '来自 $path';
  }

  @override
  String get diffTruncated => '差异太大，只显示了一部分。';

  @override
  String get binaryDiff => '二进制文件';

  @override
  String get gitModified => '已修改';

  @override
  String get gitAdded => '新增';

  @override
  String get gitDeleted => '已删除';

  @override
  String get gitRenamed => '重命名';

  @override
  String get gitUntracked => '未跟踪';

  @override
  String get gitConflicted => '冲突';

  @override
  String get gitIgnored => '已忽略';

  @override
  String gitOperationFailed(String message) {
    return 'Git：$message';
  }

  @override
  String conflictsBanner(int count) {
    return '$count 个文件有冲突';
  }

  @override
  String get terminalTitle => '终端';

  @override
  String get terminalWarningTitle => '终端会绕过审批';

  @override
  String get terminalWarningBody =>
      '终端里跑的是电脑上真正的 CLI。权限提示由它自己在终端里回应，手机上的审批卡片不会出现，也不会拦下任何操作。只有电脑端为这台手机打开了「终端」权限才能使用，默认是不给的。';

  @override
  String get terminalOpen => '我明白，打开终端';

  @override
  String get terminalClose => '关闭终端';

  @override
  String get terminalOpening => '正在打开终端…';

  @override
  String terminalExitCode(int code) {
    return '已结束 · 退出码 $code';
  }

  @override
  String terminalExitSignal(int signal) {
    return '已结束 · 被信号 $signal 终止';
  }

  @override
  String get terminalEnded => '已结束';

  @override
  String get terminalNotAllowed => '这台手机没有终端权限。';

  @override
  String get historyTitle => '历史';

  @override
  String get historySubtitle => '存在服务器上的密文，只有这台手机能解开';

  @override
  String get historySearch => '在已打开的记录中搜索';

  @override
  String historyEpoch(int epoch) {
    return '第 $epoch 代密钥';
  }

  @override
  String historyTurns(int count) {
    return '$count 个回合';
  }

  @override
  String get historyEmpty => '服务器上没有历史';

  @override
  String historyNoKey(int epoch) {
    return '这台手机没有第 $epoch 代历史密钥，等电脑端重新上传后再看。';
  }

  @override
  String historyDownload(String error) {
    return '无法下载：$error';
  }

  @override
  String get historyEncoding => '存储的数据格式无效。';

  @override
  String get historyDecrypt => '解密失败：这段历史可能属于别的会话或密钥代。';

  @override
  String get historyContent => '已解密，但内容不是会话。';

  @override
  String get historyNotOpened => '点按下载并解密';

  @override
  String get historyNoHost => '请先连接一台电脑。';

  @override
  String get settingsTitle => '设置';

  @override
  String get account => '账号';

  @override
  String get signOut => '退出登录';

  @override
  String get signOutTitle => '退出登录？';

  @override
  String get signOutBody => '配对记录会留在这台手机上，再次登录后恢复。';

  @override
  String get security => '安全';

  @override
  String get keyProtected => '这台手机的私钥由系统密钥库保管，无法导出。';

  @override
  String get biometricLock => '打开应用时要求解锁';

  @override
  String get biometricLockHint => '只是便利锁，密钥本身不依赖它。';

  @override
  String get appearance => '外观';

  @override
  String get designStyle => '设计风格';

  @override
  String get styleM3 => 'Material 3';

  @override
  String get styleM3E => 'Material 3 Expressive';

  @override
  String get styleM3Hint => '沉稳、紧凑、熟悉';

  @override
  String get styleM3EHint => '更大胆的形状、弹性动效、强调字体';

  @override
  String get themeMode => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get dynamicColor => '壁纸取色';

  @override
  String get dynamicColorHint => '使用壁纸的颜色（Android 12 及以上）';

  @override
  String get seedColor => '主题色';

  @override
  String seedColorOption(int number) {
    return '颜色 $number';
  }

  @override
  String get colorVariant => '配色';

  @override
  String get variantTonalSpot => '柔和';

  @override
  String get variantVibrant => '鲜明';

  @override
  String get variantExpressive => '表现';

  @override
  String get variantFidelity => '保真';

  @override
  String get variantNeutral => '中性';

  @override
  String get contrast => '对比度';

  @override
  String get contrastStandard => '标准';

  @override
  String get contrastMedium => '中';

  @override
  String get contrastHigh => '高';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageZhHans => '简体中文';

  @override
  String get languageZhHant => '繁體中文';

  @override
  String get languageEn => 'English';

  @override
  String devicesOnHost(String host) {
    return '「$host」上的设备';
  }

  @override
  String get devicesConnectFirst => '连接一台电脑后，才能管理它的设备。';

  @override
  String get effectiveScopes => '这台手机实际有效的权限（服务器授予与电脑本地上限的交集）：';

  @override
  String get terminalScopeNote => '终端权限默认不授予：终端里的 CLI 会自己回答权限提示。';

  @override
  String get thisDevice => '这台手机';

  @override
  String get permissions => '权限';

  @override
  String get serverScopesNote =>
      '这里改的是服务器上的授权。实际生效的是它与电脑为这台设备设的上限的交集：电脑上没放开的权限，在这里勾上也不会生效。';

  @override
  String get savePermissions => '保存权限';

  @override
  String get noScopes => '没有权限';

  @override
  String get revoke => '撤销';

  @override
  String revokeTitle(String name) {
    return '撤销「$name」？';
  }

  @override
  String get revokeBody => '撤销后它就连不上了，需要重新扫码配对。';

  @override
  String lastSeen(String ago) {
    return '$ago在线';
  }

  @override
  String get deviceStatusPending => '待激活';

  @override
  String get deviceStatusActive => '已激活';

  @override
  String get deviceStatusRevoked => '已撤销';

  @override
  String get about => '关于';

  @override
  String version(String version) {
    return '版本 $version';
  }

  @override
  String get componentGallery => '组件画廊';

  @override
  String get reloginNote => '注销或更换账号后，需要在电脑端重新生成配对二维码。';

  @override
  String get scopeSessions => '查看会话';

  @override
  String get scopePrompt => '发送消息';

  @override
  String get scopeApprove => '审批权限请求';

  @override
  String get scopeFiles => '查看文件';

  @override
  String get scopeFilesWrite => '修改文件';

  @override
  String get scopeGit => '查看 Git';

  @override
  String get scopeGitWrite => 'Git 写操作';

  @override
  String get scopeTerminal => '终端';

  @override
  String get lockedTitle => 'SkidSense 已锁定';

  @override
  String get unlock => '解锁';

  @override
  String get unlockReason => '解锁 SkidSense';

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String hoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String daysAgo(int count) {
    return '$count 天前';
  }

  @override
  String get noticeSessionExpired => '登录已过期，请重新登录。';

  @override
  String get noticeStoreReset =>
      '这台设备上的登录信息无法读取（是从别的手机迁移过来的吗？）。已为你退出登录，请重新登录并重新配对。';

  @override
  String noticeForgetUnrevoked(String error) {
    return '已在这台手机上忘记，但服务器上的撤销没有成功（$error）。请到电脑上撤销这台手机。';
  }

  @override
  String noticeUndecodable(String method) {
    return '无法解析电脑对 $method 的回答。电脑端的 SkidSense 是最新版吗？';
  }

  @override
  String get errOffline => '未连接到电脑';

  @override
  String get errTimeout => '电脑没有及时回应';

  @override
  String errTimeoutRoute(String route) {
    return '$route：连接超时';
  }

  @override
  String errUnreachableRoute(String route) {
    return '$route：无法连接';
  }

  @override
  String errRouteReason(String route, String reason) {
    return '$route：$reason';
  }

  @override
  String get errUnreachable => '无法连接';

  @override
  String get errNoRoute => '没有可用的连接方式';

  @override
  String get errClosed => '连接已关闭';

  @override
  String get errPeerClosed => '对方关闭了连接';

  @override
  String get errIdle => '连接无响应';

  @override
  String get errHandshakeTimeout => '握手超时';

  @override
  String get errRelayFrameOnLan => '局域网上有东西冒充了中继';

  @override
  String get errPlaintextAfterHandshake => '握手确认后收到了伪造的消息';

  @override
  String errProtocol(String code) {
    return '连接校验失败（$code）';
  }

  @override
  String get errBadResponse => '电脑的回答格式有误';

  @override
  String get errTooLarge => '内容过大';

  @override
  String get errHelloRefused => '电脑拒绝了这台手机';

  @override
  String errHelloRefusedReason(String reason) {
    return '电脑拒绝了这台手机：$reason';
  }

  @override
  String get errBye => '电脑断开了连接';

  @override
  String errByeReason(String reason) {
    return '电脑断开了连接：$reason';
  }

  @override
  String get errRevoked => '这台手机已被撤销，需要重新扫码配对。';

  @override
  String get errHostGone => '服务器上已没有这次配对（电脑或这台手机已被移除），需要重新扫码配对。';

  @override
  String errGrant(String error) {
    return '无法获取授权凭证：$error';
  }

  @override
  String get errCompanionDisabled => '服务器未启用远程控制';

  @override
  String get errNoHost => '还没有选择电脑';

  @override
  String get errUploadDesync => '上传进度与电脑不一致，请重新添加这个附件。';

  @override
  String get errTooManyUploads => '同时上传的附件不能超过 8 个';

  @override
  String get errUploadTooLarge => '单个附件不能超过 20 MiB';

  @override
  String get errUploadsTooLarge => '附件合计不能超过 20 MiB';

  @override
  String get errNoKeystore => '系统密钥库不可用，无法生成设备密钥';

  @override
  String get errKeyUnreadable => '暂时读不了系统密钥库，请稍后再试。';

  @override
  String errUnknown(String detail) {
    return '出了点问题：$detail';
  }

  @override
  String get hsrUnsupportedVersion => '电脑端的协议版本与手机端不一致，请更新';

  @override
  String get hsrWrongHost => '连到的不是配对的那台电脑';

  @override
  String get hsrEnrollClosed => '配对码已失效，请在电脑上重新生成二维码';

  @override
  String get hsrUnknownDevice => '这台手机没有与该电脑配对，或已被撤销';

  @override
  String get hsrHandshakeFailed => '握手失败：配对码不对，或不是你配对的那台电脑';

  @override
  String get hsrReplayed => '握手被判为重放，请重试';

  @override
  String get hsrRateLimited => '尝试太频繁，请稍后再试';

  @override
  String get hsrDisabled => '电脑端关闭了远程控制';

  @override
  String get relayHostOffline => '电脑不在线';

  @override
  String get relayUnauthorized => '登录已失效，请重新登录';

  @override
  String get relayRevoked => '这台手机已被撤销，需要重新配对';

  @override
  String get relayRateLimited => '请求太频繁，请稍后再试';

  @override
  String get relayTooLarge => '消息过大';

  @override
  String get relaySuperseded => '这台手机在别处连上了同一台电脑';

  @override
  String get relayShutdown => '中继服务正在重启';

  @override
  String get relayHostClosed => '电脑结束了这个连接';

  @override
  String relayOther(String code) {
    return '中继拒绝了连接（$code）';
  }

  @override
  String hsrOther(String code) {
    return '电脑拒绝了连接（$code）';
  }

  @override
  String get carrierRefused => '被拒绝';

  @override
  String get carrierNoCredentials => '未登录';

  @override
  String get carrierNoRelay => '没有中继地址';

  @override
  String get carrierUpgrade => '不是 SkidSense 的连接端点';

  @override
  String get carrierTls => '安全连接失败';

  @override
  String get carrierForbidden => '服务器拒绝了这台手机';

  @override
  String get carrierNotFound => '服务器上找不到这次配对或中继端点';

  @override
  String get carrierCredentialsUnavailable => '暂时无法确认登录状态';

  @override
  String backendServer(String message) {
    return '$message';
  }

  @override
  String get backendNotSignedIn => '尚未登录';

  @override
  String get backendSessionExpired => '登录已过期，请重新登录。';

  @override
  String backendUnreachable(String base) {
    return '无法连接服务器（$base）';
  }

  @override
  String backendInsecure(String base) {
    return '$base 是未加密的 http://，登录凭据会以明文经过互联网。请使用服务器的 https:// 地址。';
  }

  @override
  String backendHttp(int status) {
    return '服务器返回 HTTP $status';
  }

  @override
  String backendRefreshFailed(int status) {
    return '暂时无法更新登录状态（HTTP $status），请稍后再试';
  }

  @override
  String backendRefreshFailedIn(int status, int seconds) {
    return '暂时无法更新登录状态（HTTP $status），请在 $seconds 秒后再试';
  }

  @override
  String backendUnparsable(String base) {
    return '服务器返回了无法解析的内容（$base 是不是填错了？）';
  }

  @override
  String get backendBadData => '服务器返回的数据格式不对';

  @override
  String get backendNoCredentials => '登录失败：服务器没有返回凭证';

  @override
  String get backendVerificationIncomplete => '登录需要二次验证，但服务器没有给出验证流程';

  @override
  String get backendVerifyFailed => '验证码错误或已过期';

  @override
  String get backendRateLimited => '请求太频繁，请稍后再试';

  @override
  String backendRateLimitedIn(int seconds) {
    return '请求太频繁，请在 $seconds 秒后再试';
  }

  @override
  String get pairErrNotSignedIn => '请先登录';

  @override
  String pairErrWrongBackend(String server, String signedIn) {
    return '这个二维码属于 $server，而你登录的是 $signedIn。两端必须登录同一个服务器。';
  }

  @override
  String get pairErrNoTicket => '服务器没有给出配对凭证，请重新生成二维码';

  @override
  String pairErrNoGrant(String error) {
    return '这台手机在这台电脑上已登记，但拿不到接入凭证（$error）。请在电脑上检查它是否已被撤销；已撤销的话请重新生成二维码。';
  }

  @override
  String pairErrCleanup(String error) {
    return '无法清理这台手机在服务器上的旧记录（$error）';
  }

  @override
  String get pairCodeInvalid => '配对码无效';

  @override
  String get pairCodeAppTooOld => '这个配对码需要更新版本的手机端';

  @override
  String get pairCodeUnsupported => '配对码版本不受支持';

  @override
  String get pairCodeBadKey => '配对码里的电脑公钥无效';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class L10nZhHant extends L10nZh {
  L10nZhHant() : super('zh_Hant');

  @override
  String get appName => 'SkidSense';

  @override
  String get ok => '好';

  @override
  String get cancel => '取消';

  @override
  String get retry => '重試';

  @override
  String get back => '返回';

  @override
  String get close => '關閉';

  @override
  String get save => '儲存';

  @override
  String get delete => '刪除';

  @override
  String get rename => '重新命名';

  @override
  String get refresh => '重新整理';

  @override
  String get copy => '複製';

  @override
  String get copied => '已複製';

  @override
  String get done => '完成';

  @override
  String get edit => '編輯';

  @override
  String get preview => '預覽';

  @override
  String get reload => '重新載入';

  @override
  String get more => '更多';

  @override
  String get search => '搜尋';

  @override
  String get clear => '清除';

  @override
  String get create => '建立';

  @override
  String get continueAction => '繼續';

  @override
  String get dismiss => '關閉';

  @override
  String get none => '—';

  @override
  String get loginTitle => '登入';

  @override
  String get loginSubtitle => '使用與電腦端 SkidSense 相同的帳號登入——兩端靠它找到彼此。';

  @override
  String get serverAddress => '伺服器';

  @override
  String serverAddressUsed(String address) {
    return '將使用 $address';
  }

  @override
  String get serverAddressInvalid => '請輸入伺服器位址，例如 https://example.com';

  @override
  String get username => '使用者名稱';

  @override
  String get password => '密碼';

  @override
  String get showPassword => '顯示密碼';

  @override
  String get hidePassword => '隱藏密碼';

  @override
  String get signIn => '登入';

  @override
  String get testConnection => '測試連線';

  @override
  String serverReachable(String name) {
    return '伺服器可用：$name';
  }

  @override
  String get captchaTitle => '真人驗證';

  @override
  String get captchaPassed => '已通過驗證';

  @override
  String get captchaRedo => '重新驗證';

  @override
  String captchaFailed(String code) {
    return '驗證失敗（$code），請重試。';
  }

  @override
  String get captchaExpired => '驗證已逾時，請重試。';

  @override
  String get captchaOnSignIn => '登入時會跳出真人驗證。';

  @override
  String get captchaLoading => '正在載入真人驗證…';

  @override
  String get captchaLoadFailed => '真人驗證載入失敗';

  @override
  String get captchaLoadFailedHint => '請檢查網路連線，然後再試一次。';

  @override
  String get passwordLoginDisabled => '這個伺服器關閉了密碼登入。';

  @override
  String get pairingAfterLogin => '登入與配對是兩個步驟：先在這裡登入，再掃描電腦上的 QR 碼。';

  @override
  String get twoFactorTitle => '兩步驟驗證';

  @override
  String get twoFactorHint => '輸入驗證器 App 中的 6 位數驗證碼，或一組備用碼。';

  @override
  String get twoFactorRequired => '這個帳號需要第二步驗證。';

  @override
  String twoFactorMethods(String methods) {
    return '可用方式：$methods';
  }

  @override
  String get verificationCode => '驗證碼';

  @override
  String get verify => '驗證';

  @override
  String get twoFactorPasskeyOnly =>
      '這個帳號的第二步驗證是通行金鑰（Passkey），App 目前還不支援。請先到網頁版開啟兩步驟驗證並綁定驗證器 App，再回到這裡用它的驗證碼登入。';

  @override
  String get hostsTitle => '我的電腦';

  @override
  String signedInAs(String user, String server) {
    return '$user · $server';
  }

  @override
  String get pairComputer => '配對電腦';

  @override
  String get pairedSection => '已配對';

  @override
  String get pairedSectionHint => '可以直接連線';

  @override
  String get otherHostsSection => '這個帳號的其他電腦';

  @override
  String get otherHostsHint => '尚未與這支手機配對';

  @override
  String get presenceOnline => '線上';

  @override
  String get presenceRelayOffline => '中繼離線';

  @override
  String get presenceOffline => '離線';

  @override
  String get presenceRelayOfflineHint => '沒有連到中繼——在區域網路中仍可能連得上。';

  @override
  String get fingerprint => '指紋';

  @override
  String get lanAddresses => '區域網路';

  @override
  String get connect => '連線';

  @override
  String get forget => '忘記';

  @override
  String forgetTitle(String name) {
    return '要忘記「$name」嗎？';
  }

  @override
  String get forgetBody =>
      '也會在伺服器上撤銷這支手機：電腦會立即中斷它，也不再為它加密歷史記錄。之後要重新掃描 QR 碼才能再連線。';

  @override
  String get forgetAction => '忘記並撤銷';

  @override
  String get noComputersTitle => '還沒有電腦';

  @override
  String get noComputersBody => '在電腦端 SkidSense 中開啟「遠端控制」並產生配對 QR 碼，再回到這裡掃描。';

  @override
  String get hostNeedsQr => '在它上面產生 QR 碼即可配對';

  @override
  String get loadingHosts => '正在讀取電腦清單…';

  @override
  String get settings => '設定';

  @override
  String get pairingTitle => '配對電腦';

  @override
  String get pairingIntro =>
      '在電腦端 SkidSense 開啟「遠端控制」，掃描視窗中的 QR 碼。QR 碼只能使用一次，10 分鐘內有效。';

  @override
  String get scanQr => '掃描 QR 碼';

  @override
  String get pasteLinkSection => '或貼上配對連結';

  @override
  String get pasteLinkLabel => 'skidsense://pair/1?d=…';

  @override
  String get readLink => '讀取連結';

  @override
  String get confirmComputer => '是這台電腦嗎？';

  @override
  String get machineName => '名稱';

  @override
  String get backend => '伺服器';

  @override
  String get fingerprintCheck =>
      '請與電腦螢幕上顯示的指紋逐組核對。若不一致，表示這個 QR 碼不是來自你正在使用的那台電腦。';

  @override
  String get confirmPair => '配對';

  @override
  String get pairStepRegistering => '正在登記這支手機…';

  @override
  String get pairStepAlreadyRegistered => '這支手機已經登記過，正在重新連線…';

  @override
  String get pairStepHandshaking => '正在與電腦交握…';

  @override
  String get pairStepRepairing => '電腦上沒有這支手機的記錄，正在重新配對…';

  @override
  String get pairStepFinishing => '配對完成，正在讀取這支手機獲得的權限…';

  @override
  String pairStepTrying(String route) {
    return '正在嘗試$route…';
  }

  @override
  String get cameraUnavailable => '相機無法使用。請改為貼上配對連結。';

  @override
  String get scannerPrompt => '將電腦上的 QR 碼放進取景框';

  @override
  String get scannerTorch => '手電筒';

  @override
  String get notAPairingCode => '這不是 SkidSense 的配對 QR 碼。';

  @override
  String get tabSessions => '對話';

  @override
  String get tabFiles => '檔案';

  @override
  String get tabGit => 'Git';

  @override
  String get tabHistory => '歷史記錄';

  @override
  String routeLan(String address) {
    return '區域網路 $address';
  }

  @override
  String get routeRelay => '中繼';

  @override
  String statusConnected(String route) {
    return '已連線 · $route';
  }

  @override
  String statusConnectedLimited(String route, int rate) {
    return '已連線 · $route（限速 $rate KB/s）';
  }

  @override
  String statusConnecting(String route) {
    return '正在連線 · $route';
  }

  @override
  String get statusAuthorizing => '正在連線 · 取得授權';

  @override
  String statusWaiting(String error, int seconds) {
    return '$error · $seconds 秒後重試';
  }

  @override
  String statusFailed(String error) {
    return '連線失敗：$error';
  }

  @override
  String get statusIdle => '未連線';

  @override
  String get offlineTitle => '尚未連上電腦';

  @override
  String get offlineBody =>
      '請確認電腦上的 SkidSense 正在執行，且這支手機已與它配對。區域網路無法使用時會自動改走中繼。';

  @override
  String get backToComputers => '電腦';

  @override
  String get searchSessions => '搜尋對話';

  @override
  String get noSessionsTitle => '還沒有對話';

  @override
  String get noSessionsBody => '在電腦上開始一個，或在這裡建立。';

  @override
  String get noSessionsNoPrompt => '這支手機不能建立對話。';

  @override
  String noSearchResults(String query) {
    return '沒有符合「$query」的對話';
  }

  @override
  String get newSession => '新對話';

  @override
  String get workspace => '工作區';

  @override
  String get agent => '代理';

  @override
  String get titleOptional => '標題（可留空）';

  @override
  String get renameSession => '重新命名對話';

  @override
  String get sessionTitle => '標題';

  @override
  String deleteSessionTitle(String title) {
    return '要刪除「$title」嗎？';
  }

  @override
  String get deleteSessionBody => '對話和它的記錄會在電腦上刪除。';

  @override
  String backgroundJobs(int count) {
    return '$count 個背景工作';
  }

  @override
  String get loadingSessions => '正在讀取對話…';

  @override
  String get runStateRunning => '執行中';

  @override
  String get runStateAwaiting => '等你回應';

  @override
  String get runStateStarting => '啟動中';

  @override
  String get runStateIdle => '閒置';

  @override
  String get runStateDone => '已完成';

  @override
  String get runStateError => '失敗';

  @override
  String get runStateAborted => '已停止';

  @override
  String get runStatePending => '等待中';

  @override
  String get runStateCancelled => '已取消';

  @override
  String updatedAgo(String ago) {
    return '$ago更新';
  }

  @override
  String get openingSession => '正在開啟對話…';

  @override
  String get sessionNotFound => '電腦上沒有這個對話。';

  @override
  String get openTerminal => '終端機';

  @override
  String get openFiles => '檔案';

  @override
  String get openGit => 'Git';

  @override
  String get approvalPermission => '需要你的許可';

  @override
  String get approvalQuestion => '代理在提問';

  @override
  String get approvalInput => '代理在等待輸入';

  @override
  String get approvalOther => '代理需要回應';

  @override
  String get approvalFreeText => '可自由作答';

  @override
  String approvalCwd(String cwd) {
    return '工作目錄：$cwd';
  }

  @override
  String approvalScopes(String scopes) {
    return '要求的權限：$scopes';
  }

  @override
  String get approvalNoPermission => '這支手機沒有核准權限。請在電腦上回應，或改用有權限的裝置。';

  @override
  String approvalAnsweredElsewhere(String device) {
    return '已在「$device」上回應';
  }

  @override
  String get allow => '允許';

  @override
  String get deny => '拒絕';

  @override
  String get sendAnswer => '送出回答';

  @override
  String get skip => '略過';

  @override
  String get cancelTurn => '取消這一輪';

  @override
  String get answerPlaceholder => '你的回答';

  @override
  String get toolInput => '輸入';

  @override
  String get toolResult => '結果';

  @override
  String toolTruncated(String label, String size) {
    return '$label已截斷（原始 $size）';
  }

  @override
  String get messageHint => '說點什麼';

  @override
  String get steerHint => '追加到進行中的這一輪';

  @override
  String get send => '傳送';

  @override
  String get steer => '插話';

  @override
  String get stop => '停止';

  @override
  String get composerOptions => '選項';

  @override
  String get attach => '附加檔案';

  @override
  String get attachmentsNote => '附件會隨下一則訊息傳送；離開這個對話就會捨棄。';

  @override
  String get remove => '移除';

  @override
  String get noPromptPermission => '這支手機沒有傳送訊息的權限。';

  @override
  String get options => '傳送選項';

  @override
  String get model => '模型';

  @override
  String get modelDefault => '預設';

  @override
  String modelAccount(String account) {
    return '模型（$account）';
  }

  @override
  String get noModels => '沒有可選的模型清單';

  @override
  String get effort => '思考強度';

  @override
  String get effortMinimal => '最低';

  @override
  String get effortLow => '低';

  @override
  String get effortMedium => '中';

  @override
  String get effortHigh => '高';

  @override
  String get effortXhigh => '很高';

  @override
  String get effortMax => '最高';

  @override
  String get effortUltra => '極致';

  @override
  String get approvalMode => '核准方式';

  @override
  String get approvalModeLocked => '核准方式（這支手機沒有核准權限，只能使用預設）';

  @override
  String get approvalDefault => '每次詢問';

  @override
  String get approvalAcceptEdits => '自動接受編輯';

  @override
  String get approvalPlan => '僅規劃';

  @override
  String get approvalDontAsk => '不再詢問';

  @override
  String get approvalBypass => '略過所有權限';

  @override
  String get thinking => '思考過程';

  @override
  String get plan => '計畫';

  @override
  String get backgroundTasks => '背景工作';

  @override
  String usageContext(String tokens) {
    return '上下文 $tokens';
  }

  @override
  String usageOutput(String tokens) {
    return '輸出 $tokens';
  }

  @override
  String steered(String text) {
    return '插話：$text';
  }

  @override
  String get compactedAuto => '上下文已自動壓縮';

  @override
  String get compactedManual => '上下文已壓縮';

  @override
  String get subAgent => '子代理';

  @override
  String get subAgentTask => '任務';

  @override
  String get subAgentLatest => '最新發言';

  @override
  String get subAgentReport => '結果';

  @override
  String get workflow => '工作流程';

  @override
  String toolCalls(int count) {
    return '$count 次工具呼叫';
  }

  @override
  String promptRefused(String reason) {
    return '電腦沒有接受這則訊息：$reason';
  }

  @override
  String get promptRefusedPlain => '電腦沒有接受這則訊息。';

  @override
  String get promptUncertain => '沒有收到回應——這一輪可能已經開始。請先查看對話記錄，再決定是否重新傳送。';

  @override
  String get promptUncertainDropped =>
      '沒有收到回應——這一輪可能已經開始。請先查看對話記錄，再決定是否重新傳送；附件已移除，需要重新加入。';

  @override
  String uploadIncomplete(String name) {
    return '「$name」尚未上傳完成。';
  }

  @override
  String uploading(String name) {
    return '正在上傳 $name';
  }

  @override
  String get jumpToLatest => '最新';

  @override
  String get you => '你';

  @override
  String get filesTitle => '檔案';

  @override
  String get searchContent => '搜尋檔案內容';

  @override
  String get regex => '正規表示式';

  @override
  String get searching => '正在搜尋…';

  @override
  String searchSummary(int matches, int files) {
    return '$files 個檔案中 $matches 處符合';
  }

  @override
  String get searchCancelled => '已停止搜尋';

  @override
  String get searchInterrupted => '連線中斷，搜尋已停止，請重新搜尋。';

  @override
  String moreMatches(int count) {
    return '還有 $count 處';
  }

  @override
  String get dirTruncated => '這個資料夾的項目太多，只顯示一部分。';

  @override
  String get emptyDir => '這裡是空的';

  @override
  String get showIgnored => '顯示被忽略的檔案';

  @override
  String get binaryFile => '這是二進位檔案，只能預覽。';

  @override
  String get tooLargeFile => '檔案太大，無法在這裡開啟。';

  @override
  String fileLines(int count, String size) {
    return '$count 行 · $size';
  }

  @override
  String get saved => '已儲存';

  @override
  String get saveConflict => '檔案已在別處被修改，為避免覆寫，已拒絕儲存。請重新載入後再修改。';

  @override
  String get unsavedChanges => '要捨棄你的修改嗎？';

  @override
  String get discard => '捨棄';

  @override
  String get newFile => '新增檔案';

  @override
  String get newFolder => '新增資料夾';

  @override
  String get name => '名稱';

  @override
  String deleteItemTitle(String name) {
    return '要刪除「$name」嗎？';
  }

  @override
  String get deleteItemBody => '它會在電腦上被刪除。';

  @override
  String get noWorkspace => '沒有工作區';

  @override
  String get chooseWorkspace => '工作區';

  @override
  String get root => '根目錄';

  @override
  String get gitTitle => 'Git';

  @override
  String get notARepo => '這個工作區還不是 Git 儲存庫。';

  @override
  String get initRepo => '在這裡初始化儲存庫';

  @override
  String get branch => '分支';

  @override
  String detached(String sha) {
    return '分離於 $sha';
  }

  @override
  String upstream(String name) {
    return '上游 $name';
  }

  @override
  String aheadBehind(int ahead, int behind) {
    return '↑$ahead ↓$behind';
  }

  @override
  String get branches => '分支';

  @override
  String get fetch => '擷取';

  @override
  String get pull => '提取';

  @override
  String get push => '推送';

  @override
  String get switchBranch => '切換';

  @override
  String get currentBranch => '目前';

  @override
  String get remoteBranch => '遠端';

  @override
  String get changes => '變更';

  @override
  String get staged => '已暫存';

  @override
  String get unstaged => '未暫存';

  @override
  String get noChanges => '沒有可提交的變更';

  @override
  String get stage => '暫存';

  @override
  String get unstage => '取消暫存';

  @override
  String get stageAll => '全部暫存';

  @override
  String get discardChanges => '捨棄變更';

  @override
  String discardTitle(String path) {
    return '要捨棄對 $path 的變更嗎？';
  }

  @override
  String get discardBody => '這些變更會在電腦上遺失。';

  @override
  String get commit => '提交';

  @override
  String get commitMessage => '提交說明';

  @override
  String get commitStaged => '提交已暫存的變更';

  @override
  String get committed => '已提交';

  @override
  String renamedFrom(String path) {
    return '來自 $path';
  }

  @override
  String get diffTruncated => '差異太大，只顯示一部分。';

  @override
  String get binaryDiff => '二進位檔案';

  @override
  String get gitModified => '已修改';

  @override
  String get gitAdded => '新增';

  @override
  String get gitDeleted => '已刪除';

  @override
  String get gitRenamed => '已重新命名';

  @override
  String get gitUntracked => '未追蹤';

  @override
  String get gitConflicted => '衝突';

  @override
  String get gitIgnored => '已忽略';

  @override
  String gitOperationFailed(String message) {
    return 'Git：$message';
  }

  @override
  String conflictsBanner(int count) {
    return '$count 個檔案有衝突';
  }

  @override
  String get terminalTitle => '終端機';

  @override
  String get terminalWarningTitle => '終端機會略過核准';

  @override
  String get terminalWarningBody =>
      '終端機中執行的是電腦上真正的 CLI。權限提示由它自己在終端機中回應，手機上不會出現核准卡片，也不會攔下任何操作。只有在電腦端為這支手機開啟「終端機」權限時才能使用，預設是關閉的。';

  @override
  String get terminalOpen => '我了解，開啟終端機';

  @override
  String get terminalClose => '關閉終端機';

  @override
  String get terminalOpening => '正在開啟終端機…';

  @override
  String terminalExitCode(int code) {
    return '已結束 · 結束代碼 $code';
  }

  @override
  String terminalExitSignal(int signal) {
    return '已結束 · 被訊號 $signal 終止';
  }

  @override
  String get terminalEnded => '已結束';

  @override
  String get terminalNotAllowed => '這支手機沒有終端機權限。';

  @override
  String get historyTitle => '歷史記錄';

  @override
  String get historySubtitle => '以密文存放在伺服器上，只有這支手機能解開';

  @override
  String get historySearch => '在已開啟的記錄中搜尋';

  @override
  String historyEpoch(int epoch) {
    return '第 $epoch 代金鑰';
  }

  @override
  String historyTurns(int count) {
    return '$count 輪';
  }

  @override
  String get historyEmpty => '伺服器上沒有歷史記錄';

  @override
  String historyNoKey(int epoch) {
    return '這支手機沒有第 $epoch 代歷史金鑰，等電腦端重新上傳後再查看。';
  }

  @override
  String historyDownload(String error) {
    return '無法下載：$error';
  }

  @override
  String get historyEncoding => '儲存的資料格式無效。';

  @override
  String get historyDecrypt => '解密失敗：這段記錄可能屬於其他對話或金鑰代。';

  @override
  String get historyContent => '已解密，但內容不是對話。';

  @override
  String get historyNotOpened => '點一下以下載並解密';

  @override
  String get historyNoHost => '請先連線一台電腦。';

  @override
  String get settingsTitle => '設定';

  @override
  String get account => '帳號';

  @override
  String get signOut => '登出';

  @override
  String get signOutTitle => '要登出嗎？';

  @override
  String get signOutBody => '配對記錄會保留在這支手機上，再次登入後恢復。';

  @override
  String get security => '安全性';

  @override
  String get keyProtected => '這支手機的私密金鑰由系統金鑰庫保管，無法匯出。';

  @override
  String get biometricLock => '開啟 App 時要求解鎖';

  @override
  String get biometricLockHint => '只是便利用的鎖，金鑰本身不依賴它。';

  @override
  String get appearance => '外觀';

  @override
  String get designStyle => '設計風格';

  @override
  String get styleM3 => 'Material 3';

  @override
  String get styleM3E => 'Material 3 Expressive';

  @override
  String get styleM3Hint => '沉穩、緊湊、熟悉';

  @override
  String get styleM3EHint => '更大膽的形狀、彈性動態、強調字體';

  @override
  String get themeMode => '主題';

  @override
  String get themeSystem => '跟隨系統';

  @override
  String get themeLight => '淺色';

  @override
  String get themeDark => '深色';

  @override
  String get dynamicColor => '桌布配色';

  @override
  String get dynamicColorHint => '使用桌布的顏色（Android 12 以上）';

  @override
  String get seedColor => '主題色';

  @override
  String seedColorOption(int number) {
    return '顏色 $number';
  }

  @override
  String get colorVariant => '配色';

  @override
  String get variantTonalSpot => '柔和';

  @override
  String get variantVibrant => '鮮明';

  @override
  String get variantExpressive => '表現';

  @override
  String get variantFidelity => '保真';

  @override
  String get variantNeutral => '中性';

  @override
  String get contrast => '對比';

  @override
  String get contrastStandard => '標準';

  @override
  String get contrastMedium => '中';

  @override
  String get contrastHigh => '高';

  @override
  String get language => '語言';

  @override
  String get languageSystem => '跟隨系統';

  @override
  String get languageZhHans => '简体中文';

  @override
  String get languageZhHant => '繁體中文';

  @override
  String get languageEn => 'English';

  @override
  String devicesOnHost(String host) {
    return '「$host」上的裝置';
  }

  @override
  String get devicesConnectFirst => '連線一台電腦後，才能管理它的裝置。';

  @override
  String get effectiveScopes => '這支手機實際生效的權限（伺服器授予與電腦本機上限的交集）：';

  @override
  String get terminalScopeNote => '終端機權限預設不授予：終端機中的 CLI 會自己回應權限提示。';

  @override
  String get thisDevice => '這支手機';

  @override
  String get permissions => '權限';

  @override
  String get serverScopesNote =>
      '這裡修改的是伺服器上的授權。實際生效的是它與電腦為這台裝置設定的上限的交集：電腦上沒有開放的權限，在這裡勾選也不會生效。';

  @override
  String get savePermissions => '儲存權限';

  @override
  String get noScopes => '沒有權限';

  @override
  String get revoke => '撤銷';

  @override
  String revokeTitle(String name) {
    return '要撤銷「$name」嗎？';
  }

  @override
  String get revokeBody => '撤銷後它就無法連線，需要重新掃描 QR 碼配對。';

  @override
  String lastSeen(String ago) {
    return '$ago上線';
  }

  @override
  String get deviceStatusPending => '待啟用';

  @override
  String get deviceStatusActive => '已啟用';

  @override
  String get deviceStatusRevoked => '已撤銷';

  @override
  String get about => '關於';

  @override
  String version(String version) {
    return '版本 $version';
  }

  @override
  String get componentGallery => '元件展示';

  @override
  String get reloginNote => '登出或更換帳號後，需要在電腦端重新產生配對 QR 碼。';

  @override
  String get scopeSessions => '檢視對話';

  @override
  String get scopePrompt => '傳送訊息';

  @override
  String get scopeApprove => '核准權限要求';

  @override
  String get scopeFiles => '檢視檔案';

  @override
  String get scopeFilesWrite => '修改檔案';

  @override
  String get scopeGit => '檢視 Git';

  @override
  String get scopeGitWrite => 'Git 寫入操作';

  @override
  String get scopeTerminal => '終端機';

  @override
  String get lockedTitle => 'SkidSense 已鎖定';

  @override
  String get unlock => '解鎖';

  @override
  String get unlockReason => '解鎖 SkidSense';

  @override
  String get justNow => '剛剛';

  @override
  String minutesAgo(int count) {
    return '$count 分鐘前';
  }

  @override
  String hoursAgo(int count) {
    return '$count 小時前';
  }

  @override
  String daysAgo(int count) {
    return '$count 天前';
  }

  @override
  String get noticeSessionExpired => '登入已逾時，請重新登入。';

  @override
  String get noticeStoreReset =>
      '無法讀取這台裝置上的登入資料（是從其他手機移轉過來的嗎？）。已為你登出，請重新登入並重新配對。';

  @override
  String noticeForgetUnrevoked(String error) {
    return '已在這支手機上忘記，但伺服器上的撤銷沒有成功（$error）。請到電腦上撤銷這支手機。';
  }

  @override
  String noticeUndecodable(String method) {
    return '無法解析電腦對 $method 的回應。電腦端的 SkidSense 是最新版嗎？';
  }

  @override
  String get errOffline => '未連線到電腦';

  @override
  String get errTimeout => '電腦沒有及時回應';

  @override
  String errTimeoutRoute(String route) {
    return '$route：連線逾時';
  }

  @override
  String errUnreachableRoute(String route) {
    return '$route：無法連線';
  }

  @override
  String errRouteReason(String route, String reason) {
    return '$route：$reason';
  }

  @override
  String get errUnreachable => '無法連線';

  @override
  String get errNoRoute => '沒有可用的連線方式';

  @override
  String get errClosed => '連線已關閉';

  @override
  String get errPeerClosed => '對方關閉了連線';

  @override
  String get errIdle => '連線沒有回應';

  @override
  String get errHandshakeTimeout => '交握逾時';

  @override
  String get errRelayFrameOnLan => '區域網路上有東西冒充了中繼';

  @override
  String get errPlaintextAfterHandshake => '交握確認後收到偽造的訊息';

  @override
  String errProtocol(String code) {
    return '連線驗證失敗（$code）';
  }

  @override
  String get errBadResponse => '電腦的回應格式有誤';

  @override
  String get errTooLarge => '內容過大';

  @override
  String get errHelloRefused => '電腦拒絕了這支手機';

  @override
  String errHelloRefusedReason(String reason) {
    return '電腦拒絕了這支手機：$reason';
  }

  @override
  String get errBye => '電腦中斷了連線';

  @override
  String errByeReason(String reason) {
    return '電腦中斷了連線：$reason';
  }

  @override
  String get errRevoked => '這支手機已被撤銷，需要重新掃描 QR 碼配對。';

  @override
  String get errHostGone => '伺服器上已沒有這次配對（電腦或這支手機已被移除），需要重新掃描 QR 碼配對。';

  @override
  String errGrant(String error) {
    return '無法取得授權憑證：$error';
  }

  @override
  String get errCompanionDisabled => '伺服器未啟用遠端控制';

  @override
  String get errNoHost => '尚未選擇電腦';

  @override
  String get errUploadDesync => '上傳進度與電腦不一致，請重新加入這個附件。';

  @override
  String get errTooManyUploads => '同時上傳的附件不能超過 8 個';

  @override
  String get errUploadTooLarge => '單一附件不能超過 20 MiB';

  @override
  String get errUploadsTooLarge => '附件合計不能超過 20 MiB';

  @override
  String get errNoKeystore => '系統金鑰庫無法使用，無法產生裝置金鑰';

  @override
  String get errKeyUnreadable => '暫時無法讀取系統金鑰庫，請稍後再試。';

  @override
  String errUnknown(String detail) {
    return '發生問題：$detail';
  }

  @override
  String get hsrUnsupportedVersion => '電腦端的協定版本與手機端不一致，請更新';

  @override
  String get hsrWrongHost => '連到的不是配對的那台電腦';

  @override
  String get hsrEnrollClosed => '配對碼已失效，請在電腦上重新產生 QR 碼';

  @override
  String get hsrUnknownDevice => '這支手機沒有與該電腦配對，或已被撤銷';

  @override
  String get hsrHandshakeFailed => '交握失敗：配對碼錯誤，或不是你配對的那台電腦';

  @override
  String get hsrReplayed => '交握被判定為重放，請重試';

  @override
  String get hsrRateLimited => '嘗試過於頻繁，請稍後再試';

  @override
  String get hsrDisabled => '電腦端關閉了遠端控制';

  @override
  String get relayHostOffline => '電腦不在線上';

  @override
  String get relayUnauthorized => '登入已失效，請重新登入';

  @override
  String get relayRevoked => '這支手機已被撤銷，需要重新配對';

  @override
  String get relayRateLimited => '請求過於頻繁，請稍後再試';

  @override
  String get relayTooLarge => '訊息過大';

  @override
  String get relaySuperseded => '這支手機在別處連上了同一台電腦';

  @override
  String get relayShutdown => '中繼服務正在重新啟動';

  @override
  String get relayHostClosed => '電腦結束了這個連線';

  @override
  String relayOther(String code) {
    return '中繼拒絕了連線（$code）';
  }

  @override
  String hsrOther(String code) {
    return '電腦拒絕了連線（$code）';
  }

  @override
  String get carrierRefused => '被拒絕';

  @override
  String get carrierNoCredentials => '尚未登入';

  @override
  String get carrierNoRelay => '沒有中繼位址';

  @override
  String get carrierUpgrade => '不是 SkidSense 的連線端點';

  @override
  String get carrierTls => '安全連線失敗';

  @override
  String get carrierForbidden => '伺服器拒絕了這支手機';

  @override
  String get carrierNotFound => '伺服器上找不到這次配對或中繼端點';

  @override
  String get carrierCredentialsUnavailable => '暫時無法確認登入狀態';

  @override
  String backendServer(String message) {
    return '$message';
  }

  @override
  String get backendNotSignedIn => '尚未登入';

  @override
  String get backendSessionExpired => '登入已逾時，請重新登入。';

  @override
  String backendUnreachable(String base) {
    return '無法連線到伺服器（$base）';
  }

  @override
  String backendInsecure(String base) {
    return '$base 是未加密的 http://，登入憑證會以明文經過網際網路。請使用伺服器的 https:// 位址。';
  }

  @override
  String backendHttp(int status) {
    return '伺服器回傳 HTTP $status';
  }

  @override
  String backendRefreshFailed(int status) {
    return '暫時無法更新登入狀態（HTTP $status），請稍後再試';
  }

  @override
  String backendRefreshFailedIn(int status, int seconds) {
    return '暫時無法更新登入狀態（HTTP $status），請於 $seconds 秒後再試';
  }

  @override
  String backendUnparsable(String base) {
    return '伺服器回傳了無法解析的內容（$base 是不是填錯了？）';
  }

  @override
  String get backendBadData => '伺服器回傳的資料格式不正確';

  @override
  String get backendNoCredentials => '登入失敗：伺服器沒有回傳憑證';

  @override
  String get backendVerificationIncomplete => '登入需要第二步驗證，但伺服器沒有提供驗證流程';

  @override
  String get backendVerifyFailed => '驗證碼錯誤或已逾時';

  @override
  String get backendRateLimited => '請求太頻繁，請稍後再試';

  @override
  String backendRateLimitedIn(int seconds) {
    return '請求太頻繁，請於 $seconds 秒後再試';
  }

  @override
  String get pairErrNotSignedIn => '請先登入';

  @override
  String pairErrWrongBackend(String server, String signedIn) {
    return '這個 QR 碼屬於 $server，而你登入的是 $signedIn。兩端必須登入同一個伺服器。';
  }

  @override
  String get pairErrNoTicket => '伺服器沒有提供配對憑證，請重新產生 QR 碼';

  @override
  String pairErrNoGrant(String error) {
    return '這支手機已在這台電腦上登記，但取不到存取憑證（$error）。請在電腦上確認它是否已被撤銷；若已撤銷，請重新產生 QR 碼。';
  }

  @override
  String pairErrCleanup(String error) {
    return '無法清除這支手機在伺服器上的舊記錄（$error）';
  }

  @override
  String get pairCodeInvalid => '配對碼無效';

  @override
  String get pairCodeAppTooOld => '這個配對碼需要更新版本的手機端';

  @override
  String get pairCodeUnsupported => '不支援這個配對碼版本';

  @override
  String get pairCodeBadKey => '配對碼中的電腦公開金鑰無效';
}
