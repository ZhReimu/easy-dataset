#!/bin/bash
set -e

# 定义构建标记文件
BUILD_MARKER="/app/.build-completed"

# 只有在设置了 MYSQL_URL 时才进行 MySQL 相关配置
if [ -n "$MYSQL_URL" ]; then
  echo "检测到 MYSQL_URL，配置 MySQL 数据库"

  # 替换 /app/.env 中的 DATABASE_URL
  if [ -f "/app/.env" ]; then
    echo "替换数据库连接为 MySQL"
    sed -i "s|^DATABASE_URL=.*|DATABASE_URL=\"$MYSQL_URL\"|" /app/.env
  else
    echo "警告: /app/.env 文件不存在"
  fi

  # 替换 schema.prisma 中的数据库类型
  if [ -f "/app/prisma/schema.prisma" ]; then
    echo "更新 Prisma 数据库类型为 MySQL"
    # 更改 provider
    sed -i 's|provider = "sqlite"|provider = "mysql"|' /app/prisma/schema.prisma

    # 检查是否已经存在 relationMode，避免重复添加
    if ! grep -q "relationMode" /app/prisma/schema.prisma; then
      # 在 url 行后添加 relationMode
      sed -i '/url.*=.*env("DATABASE_URL")/a\  relationMode = "prisma"' /app/prisma/schema.prisma
    fi

    # 修复 Tags 模型的自引用关系
    echo "修复 Tags 模型的自引用关系"
    sed -i 's/@relation("Tags", fields: \[parentId\], references: \[id\])/@relation("Tags", fields: [parentId], references: [id], onDelete: NoAction, onUpdate: NoAction)/' /app/prisma/schema.prisma

    echo "为长文本字段添加数据库类型注解"

    # Projects 模型 - 带默认值的使用 VarChar(1000)，其他使用 Text
    sed -i '/^model Projects/,/^model/ {
      s/name\s\+String$/name String @db.VarChar(500)/
      s/description\s\+String$/description String @db.Text/
      s/globalPrompt\s\+String\s\+@default("")/globalPrompt String @default("") @db.VarChar(1000)/
      s/questionPrompt\s\+String\s\+@default("")/questionPrompt String @default("") @db.VarChar(1000)/
      s/answerPrompt\s\+String\s\+@default("")/answerPrompt String @default("") @db.VarChar(1000)/
      s/labelPrompt\s\+String\s\+@default("")/labelPrompt String @default("") @db.VarChar(1000)/
      s/domainTreePrompt\s\+String\s\+@default("")/domainTreePrompt String @default("") @db.VarChar(1000)/
      s/test\s\+String\s\+@default("")/test String @default("") @db.VarChar(1000)/
    }' /app/prisma/schema.prisma

    # UploadFiles 模型
    sed -i '/^model UploadFiles/,/^model/ {
      s/fileName\s\+String$/fileName String @db.VarChar(500)/
      s/path\s\+String$/path String @db.VarChar(1000)/
    }' /app/prisma/schema.prisma

    # Chunks 模型
    sed -i '/^model Chunks/,/^model/ {
      s/name\s\+String$/name String @db.VarChar(500)/
      s/fileName\s\+String$/fileName String @db.VarChar(500)/
      s/content\s\+String$/content String @db.Text/
      s/summary\s\+String$/summary String @db.Text/
    }' /app/prisma/schema.prisma

    # Tags 模型
    sed -i '/^model Tags/,/^model/ {
      s/label\s\+String$/label String @db.VarChar(500)/
    }' /app/prisma/schema.prisma

    # Questions 模型
    sed -i '/^model Questions/,/^model/ {
      s/question\s\+String$/question String @db.Text/
      s/label\s\+String$/label String @db.VarChar(500)/
    }' /app/prisma/schema.prisma

    # Datasets 模型
    sed -i '/^model Datasets/,/^model/ {
      s/question\s\+String$/question String @db.Text/
      s/answer\s\+String$/answer String @db.Text/
      s/chunkName\s\+String$/chunkName String @db.VarChar(500)/
      s/chunkContent\s\+String$/chunkContent String @db.Text/
      s/questionLabel\s\+String$/questionLabel String @db.VarChar(500)/
      s/cot\s\+String$/cot String @db.Text/
    }' /app/prisma/schema.prisma

    # LlmProviders 模型
    sed -i '/^model LlmProviders/,/^model/ {
      s/apiUrl\s\+String$/apiUrl String @db.VarChar(1000)/
    }' /app/prisma/schema.prisma

    # ModelConfig 模型
    sed -i '/^model ModelConfig/,/^model/ {
      s/endpoint\s\+String$/endpoint String @db.VarChar(1000)/
      s/apiKey\s\+String$/apiKey String @db.VarChar(500)/
    }' /app/prisma/schema.prisma

    # Task 模型 - 带默认值的使用 VarChar(1000)
    sed -i '/^model Task/,/^model/ {
      s/modelInfo\s\+String/modelInfo String @db.Text/
      s/detail\s\+String\s\+@default("")/detail String @default("") @db.VarChar(1000)/
      s/note\s\+String\s\+@default("")/note String @default("") @db.VarChar(1000)/
    }' /app/prisma/schema.prisma

    # GaPairs 模型
    sed -i '/^model GaPairs/,/^}/ {
      s/genreTitle\s\+String/genreTitle String @db.VarChar(200)/
      s/genreDesc\s\+String/genreDesc String @db.Text/
      s/audienceTitle\s\+String/audienceTitle String @db.VarChar(200)/
      s/audienceDesc\s\+String/audienceDesc String @db.Text/
    }' /app/prisma/schema.prisma
  fi
else
  echo "未检测到 MYSQL_URL，使用默认的 SQLite 配置"
fi

# 检查是否已经构建过
if [ -f "$BUILD_MARKER" ]; then
  echo "检测到已完成构建，跳过构建步骤"
else
  # 构建应用
  echo "开始构建应用..."
  rm -rf .next public
  pnpm build

  # 创建构建标记
  touch "$BUILD_MARKER"
  echo "构建完成，已创建标记文件"
fi

# 启动应用
echo "正在启动应用..."
exec pnpm start-docker