#!/usr/bin/env bash
# Prepara Google Cloud para que GitHub publique las funciones de Kioku
# (avisos con la app cerrada). Se ejecuta UNA vez en Cloud Shell:
#   bash <(curl -s https://raw.githubusercontent.com/labappsch-create/kioku/main/herramientas/preparar_avisos.sh)
# Se puede repetir sin problema.
set -u

PROYECTO=kioku-5d311
NUMERO=693831196987
REPO=labappsch-create/kioku
CUENTA="github-deploy@${PROYECTO}.iam.gserviceaccount.com"
SERVIDOR="${NUMERO}-compute@developer.gserviceaccount.com"
FALLAS=0
LOG=$(mktemp)

paso() {
  local texto="$1"; shift
  if "$@" >"$LOG" 2>&1; then
    echo "✓ $texto"
  elif grep -qiE "already exists|ALREADY_EXISTS" "$LOG"; then
    echo "✓ $texto (ya estaba)"
  else
    echo "✗ $texto"
    tail -n 4 "$LOG" | sed 's/^/    /'
    FALLAS=$((FALLAS + 1))
  fi
}

permiso() {
  paso "Permiso $2 para $1" gcloud projects add-iam-policy-binding "$PROYECTO" \
    --member="serviceAccount:$1" --role="$2" --condition=None --quiet
}

echo "Preparando Kioku… (tarda unos minutos)"
gcloud config set project "$PROYECTO" >/dev/null 2>&1

paso "Activar los servicios de Google" gcloud services enable \
  cloudfunctions.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com \
  run.googleapis.com eventarc.googleapis.com pubsub.googleapis.com compute.googleapis.com \
  iamcredentials.googleapis.com sts.googleapis.com fcm.googleapis.com \
  cloudbilling.googleapis.com cloudresourcemanager.googleapis.com firebase.googleapis.com \
  firebaseextensions.googleapis.com

paso "Crear la cuenta que usa GitHub" gcloud iam service-accounts create github-deploy \
  --display-name="GitHub - publicar Kioku"

# Lo que necesita GitHub para publicar las funciones.
for ROL in roles/cloudfunctions.admin roles/run.admin roles/iam.serviceAccountUser \
  roles/artifactregistry.admin roles/eventarc.admin roles/serviceusage.serviceUsageConsumer \
  roles/firebase.viewer roles/iam.securityReviewer roles/cloudbuild.builds.editor; do
  permiso "$CUENTA" "$ROL"
done

# Lo que necesitan las funciones mientras trabajan.
for ROL in roles/eventarc.eventReceiver roles/run.invoker roles/cloudbuild.builds.builder \
  roles/datastore.user roles/firebasecloudmessaging.admin roles/firebaseauth.viewer; do
  permiso "$SERVIDOR" "$ROL"
done
permiso "service-${NUMERO}@gcp-sa-pubsub.iam.gserviceaccount.com" roles/iam.serviceAccountTokenCreator

paso "Crear la conexión con GitHub" gcloud iam workload-identity-pools create github \
  --location=global --display-name="GitHub"
paso "Configurar la conexión con GitHub" gcloud iam workload-identity-pools providers create-oidc github \
  --location=global --workload-identity-pool=github --display-name="GitHub" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref" \
  --attribute-condition="assertion.repository=='${REPO}' && assertion.ref=='refs/heads/main'"
paso "Permitir que solo tu repositorio use la cuenta" gcloud iam service-accounts add-iam-policy-binding "$CUENTA" \
  --role=roles/iam.workloadIdentityUser --quiet \
  --member="principalSet://iam.googleapis.com/projects/${NUMERO}/locations/global/workloadIdentityPools/github/attribute.repository/${REPO}"

echo
if [ "$FALLAS" -eq 0 ]; then
  echo "LISTO ✓ Ya puedes volver a Kiro."
else
  echo "Hubo $FALLAS problema(s). Espera 1 minuto y vuelve a pegar el mismo comando."
  echo "Si se repite, manda una captura a Kiro."
fi
rm -f "$LOG"
