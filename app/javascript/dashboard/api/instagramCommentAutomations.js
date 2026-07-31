import ApiClient from './ApiClient';

class InstagramCommentAutomationsAPI extends ApiClient {
  constructor() {
    super('instagram_comment_automations', { accountScoped: true });
  }
}

export default new InstagramCommentAutomationsAPI();
