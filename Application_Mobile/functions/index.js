/* eslint-disable */

// index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Fonction déclenchée lors de la modification d'un document dans la collection "Colliers" de l'utilisateur
exports.sendCollierNotification = functions.firestore
  .document('Utilisateurs/{userEmail}/Colliers/{collierId}')
  .onUpdate((change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Vérifier que le champ is_inside_polygon a changé
    if (beforeData.is_inside_polygon === afterData.is_inside_polygon) {
      return null;
    }
    
    const isInside = afterData.is_inside_polygon;
    const messageBody = isInside ? 'Coucou Magood' : 'Au revoir magood';
    const userEmail = context.params.userEmail;

    // Récupérer le token FCM depuis le document utilisateur principal
    const userDocRef = admin.firestore().collection('Utilisateurs').doc(userEmail);
    return userDocRef.get().then(doc => {
      if (!doc.exists) {
        console.log(`Document pour l'utilisateur ${userEmail} non trouvé.`);
        return null;
      }
      const token = doc.data().FCM_token;
      if (!token) {
        console.log(`Aucun token FCM pour l'utilisateur ${userEmail}.`);
        return null;
      }
      
      const payload = {
        notification: {
          title: 'Mise à jour du collier',
          body: messageBody,
          sound: 'default'
        },
      };

      // Envoi de la notification à l'appareil via son token
      return admin.messaging().sendToDevice(token, payload)
        .then(response => {
          console.log('Notification envoyée avec succès:', response);
          return null;
        })
        .catch(error => {
          console.log('Erreur lors de l’envoi de la notification:', error);
          return null;
        });
    });
  });
