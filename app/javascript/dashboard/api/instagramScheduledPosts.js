import axios from 'axios';
import ApiClient from './ApiClient';

class InstagramScheduledPostsAPI extends ApiClient {
  constructor() {
    super('instagram_scheduled_posts', { accountScoped: true });
  }

  // Sobe uma imagem (base64/dataURL) pro ImageKit e devolve { url }.
  upload(file, fileName) {
    return axios.post(`${this.url}/upload`, { file, file_name: fileName });
  }
}

export default new InstagramScheduledPostsAPI();
