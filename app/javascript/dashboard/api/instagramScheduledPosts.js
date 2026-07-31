import axios from 'axios';
import ApiClient from './ApiClient';

class InstagramScheduledPostsAPI extends ApiClient {
  constructor() {
    super('instagram_scheduled_posts', { accountScoped: true });
  }

  // Assinatura pro upload client-side do ImageKit (token/expire/signature/public_key).
  imagekitAuth() {
    return axios.get(`${this.url}/imagekit_auth`);
  }
}

export default new InstagramScheduledPostsAPI();
