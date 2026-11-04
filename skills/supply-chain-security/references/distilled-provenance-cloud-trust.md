# 供应链与云身份：产物、签名者和信任条件

本篇扩充 [CI/CD 审计参考](cicd-pipeline-security.md)，将验证对象与信任策略拆到可核对字段；云身份流另参 [既有 SSO 清单](../../identity-federation/references/sso-flow-checklist.md)。引入批次：首批全领域增补；引入版本待独立 release PR 分配。

## DK-SC-01：provenance 必须绑定正在使用的产物

**现象→判定：** 找到了构建证明且签名有效，仍不能认定当前下载物来自预期构建。SLSA 要求把 statement 的 subject 与实际产物摘要匹配，并按已配置信任根核验签名、builder 身份和构建条件。

**方法：** 独立计算待使用文件的摘要，再比较 subject、predicateType、builder.id、buildType 与 externalParameters；将未知参数作为审阅阻断项。记录信任根为何认可该构建平台，不用证明文件自称的等级替代验证策略。

**版本/边界/反例：** 依据 SLSA v1.2 的验证说明和 provenance/v1。可信构建仍可能忠实构建恶意源码；SLSA 等级不是漏洞扫描结果。同版本号的另一份包、摘要不符或未预期的构建参数，都不能因签名通过而放行。

**验证状态：未验证。** 原文来源：[S24：SLSA v1.2 验证产物](https://slsa.dev/spec/v1.2/verifying-artifacts)。

## DK-SC-02：无密钥签名仍需指定预期身份

**现象→判定：** cosign 验签成功只在所用身份与信任策略下有意义。合法证书和透明日志记录不自动证明签名者就是预期发布方；产物摘要、签名与身份三者需要同时绑定。

**方法：** 为验证准备明确的 certificate identity 和 OIDC issuer；对 blob 使用对应文件及 bundle，对镜像核实际 digest。设计错文件、错 identity、错 issuer 的拒绝对照；失败时保留输出，不能通过放宽身份匹配或关闭 claims 检查制造成功。

**版本/边界/反例：** 对照当前 Sigstore 文档；cosign 具体版本、bundle 格式和信任材料需另固定。发行方身份匹配只证明该身份签署了这份材料，不证明软件无恶意。过宽正则或跳过摘要检查会改变验证承诺，不能沿用原结论。

**验证状态：未验证。** 原文来源：[S25：Sigstore 身份约束与 blob 验证](https://docs.sigstore.dev/cosign/verifying/verify/)。

## DK-SC-03：OIDC 的短期令牌不自动缩小授权范围

**现象→判定：** CI 改用 OIDC 后没有长期密钥，仍可能因云端 trust policy 过宽而授权错误工作流。GitHub 对 AWS 的说明要求检查 aud，并用 sub 约束可承担角色的来源。

**方法：** 先核 issuer 和实际 claim 形状，再比对预期仓库、ref 或 environment；环境型 sub 应配合环境保护规则，而非继续假定它携带分支身份。将身份允许条件和云角色实际权限分别审阅，预备正确来源、其他分支/环境和错误 audience 的对照。

**版本/边界/反例：** 仅限 GitHub Actions→AWS 所引流程；subject 模板可定制，迁移或加入不可变标识后需重核，不能永久写死示例字符串。`repo:*` 的宽匹配会扩大信任面；STS 换取成功只说明该次身份交换被接受，不证明最小权限或业务操作合规。

**验证状态：未验证。** 原文来源：[S26：GitHub 的 AWS OIDC aud/sub 与环境规则](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws)。
