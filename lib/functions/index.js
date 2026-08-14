const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

exports.notifyNewNews = onDocumentCreated('news/{newsId}', async (event) => {
  const data = event.data?.data();
  if (!data) return;

  const title = String(data.title || '').trim();
  const category = String(data.category || '').trim();
  const breaking = data.breaking === true;

  if (!title) return;

  const prefix = breaking ? 'BREAKING • ' : '';
  const body = `${prefix}${category ? category + ' • ' : ''}${title}`;

  await getMessaging().send({
    topic: 'all_news',
    notification: {
      title: 'SRI NEWS',
      body,
    },
    data: {
      newsId: event.params.newsId,
      title,
      category,
      breaking: String(breaking),
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'sri_news_channel',
        sound: 'default',
        tag: 'sri-news',
      },
    },
  });
});
