module aptos_blog_demo::article_delete_logic {
    use aptos_blog_demo::blog_state_aggregate;
    use aptos_blog_demo::article;

    friend aptos_blog_demo::article_aggregate;

    public(friend) fun verify(
        account: &signer,
        article: &article::Article,
    ): article::ArticleDeleted {
        let _ = account;
        article::new_article_deleted(
            article,
        )
    }

    public(friend) fun mutate(
        _account: &signer,
        article_deleted: &article::ArticleDeleted,
        article: article::Article,
    ): article::Article {
        let article_id = article::article_id(&article);
        let _ = article_id;
        let _ = article_deleted;
        blog_state_aggregate::remove_article(article::article_id(&article));
        article
    }

}
