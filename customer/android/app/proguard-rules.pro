# Regole di R8 per la compilazione in release (18/09/2026).
#
# flutter_stripe si porta dietro il ponte React Native di Stripe, che nomina
# le classi del "push provisioning" (la carta Stripe aggiunta al Wallet del
# telefono). Quel pezzo e' una libreria a parte, che noi non usiamo e non
# includiamo: R8 trova i riferimenti, non trova le classi e ferma la
# compilazione con "Missing class ... PushProvisioningActivityStarter".
# Questa riga gli dice che quelle assenze sono volute.
# Si copre TUTTO il pacchetto e non le singole classi: R8 le segnala poche per
# volta e a ogni giro ne salta fuori un'altra (elencate una per una, il primo
# tentativo del 18/09 ne ha mancata una e la compilazione e' fallita di nuovo).
-dontwarn com.stripe.android.pushProvisioning.**

# Il foglio di pagamento di Stripe costruisce le proprie schermate per nome
# (riflessione): senza questo, R8 le rinomina e il foglio si apre vuoto o va
# in errore solo nella build di release, dove e' piu' difficile accorgersene.
-keep class com.stripe.android.** { *; }
-keep class com.reactnativestripesdk.** { *; }
