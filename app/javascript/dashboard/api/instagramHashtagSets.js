import ApiClient from './ApiClient';

class InstagramHashtagSetsAPI extends ApiClient {
  constructor() {
    super('instagram_hashtag_sets', { accountScoped: true });
  }
}

export default new InstagramHashtagSetsAPI();
