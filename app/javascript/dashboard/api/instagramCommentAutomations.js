/* global axios */
import ApiClient from './ApiClient';

class InstagramCommentAutomationsAPI extends ApiClient {
  constructor() {
    super('instagram_comment_automations', { accountScoped: true });
  }

  // Assinatura pro upload client-side do ImageKit (capa do card da DM).
  imagekitAuth() {
    return axios.get(`${this.url}/imagekit_auth`);
  }
}

export default new InstagramCommentAutomationsAPI();
