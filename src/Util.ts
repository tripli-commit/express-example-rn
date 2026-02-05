/**
 * 工具类
 */
class Util {
  private static cachedUserID: string | null = null;

  /**
   * 获取随机用户 ID
   * 格式: user_xxx (xxx为三位数，范围100-999)
   * 首次调用时生成随机 ID 并缓存，后续调用直接返回缓存的 ID
   * @returns {string} 用户 ID
   */
  static getRandomUserID(): string {
    if (!this.cachedUserID) {
      const randomNum = Math.floor(Math.random() * 900) + 100; // 生成 100-999 的随机数
      this.cachedUserID = `user_${randomNum}`;
    }
    return this.cachedUserID;
  }
}

export default Util;
