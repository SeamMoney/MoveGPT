module aptos_blog_demo::blog_state_remove_article_logic {
    use std::vector;

    use aptos_blog_demo::article_removed_from_blog;
    use aptos_blog_demo::blog_state;

    friend aptos_blog_demo::blog_state_aggregate;

    public(friend) fun verify(
        article_id: u128,
        blog_state: &blog_state::BlogState,
    ): blog_state::ArticleRemovedFromBlog {
        blog_state::new_article_removed_from_blog(
            blog_state,
            article_id,
        )
    }

    public(friend) fun mutate(
        article_removed_from_blog: &blog_state::ArticleRemovedFromBlog,
        blog_state: blog_state::BlogState,
    ): blog_state::BlogState {
        let article_id = article_removed_from_blog::article_id(article_removed_from_blog);
        let articles = blog_state::articles(&blog_state);
        let (found, idx) = vector::index_of(&articles, &article_id);
        if (found) {
            vector::remove(&mut articles, idx);
            blog_state::set_articles(&mut blog_state, articles);
        };
        blog_state
    }
}
