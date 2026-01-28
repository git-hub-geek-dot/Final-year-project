-- CreateTable
CREATE TABLE "event_responsibilities" (
    "id" SERIAL NOT NULL,
    "event_id" INTEGER NOT NULL,
    "responsibility" VARCHAR(255) NOT NULL,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "event_responsibilities_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "idx_event_responsibilities_event_id" ON "event_responsibilities"("event_id");

-- AddForeignKey
ALTER TABLE "event_responsibilities" ADD CONSTRAINT "event_responsibilities_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;
