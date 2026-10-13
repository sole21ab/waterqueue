-- CreateEnum
CREATE TYPE "Role" AS ENUM ('resident', 'admin');

-- CreateEnum
CREATE TYPE "VoteType" AS ENUM ('confirm', 'contradict');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "email" VARCHAR(255) NOT NULL,
    "password_hash" VARCHAR(255) NOT NULL,
    "role" "Role" NOT NULL DEFAULT 'resident',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "water_points" (
    "id" UUID NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "address" VARCHAR(500) NOT NULL,
    "latitude" DECIMAL(10,8) NOT NULL,
    "longitude" DECIMAL(11,8) NOT NULL,
    "operating_hours" VARCHAR(100) NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "water_points_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reports" (
    "id" UUID NOT NULL,
    "water_point_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "water_available" BOOLEAN NOT NULL,
    "queue_size" INTEGER NOT NULL,
    "estimated_wait_minutes" INTEGER,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "reports_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "reports"
ADD CONSTRAINT "reports_queue_size_check"
CHECK ("queue_size" >= 0 AND "queue_size" <= 50);

ALTER TABLE "reports"
ADD CONSTRAINT "reports_estimated_wait_minutes_check"
CHECK ("estimated_wait_minutes" IS NULL OR "estimated_wait_minutes" >= 0);

-- CreateTable
CREATE TABLE "votes" (
    "id" UUID NOT NULL,
    "report_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "vote_type" "VoteType" NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "votes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE INDEX "water_points_is_active_idx" ON "water_points"("is_active");

-- CreateIndex
CREATE INDEX "reports_water_point_id_created_at_idx" ON "reports"("water_point_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "reports_user_id_idx" ON "reports"("user_id");

-- CreateIndex
CREATE INDEX "votes_report_id_idx" ON "votes"("report_id");

-- CreateIndex
CREATE UNIQUE INDEX "votes_report_id_user_id_key" ON "votes"("report_id", "user_id");

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_water_point_id_fkey" FOREIGN KEY ("water_point_id") REFERENCES "water_points"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "votes" ADD CONSTRAINT "votes_report_id_fkey" FOREIGN KEY ("report_id") REFERENCES "reports"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "votes" ADD CONSTRAINT "votes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
