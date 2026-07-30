import ApiClient from './ApiClient';

class InstagramCommentedPostsAPI extends ApiClient {
  constructor() {
    super('instagram_commented_posts', { accountScoped: true });
  }

  // get()        -> galeria (posts agrupados com contagem)
  // show(mediaId) -> detalhe do post (post + thread de comentarios)
}

export default new InstagramCommentedPostsAPI();
