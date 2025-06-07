set -e

# 替换 /app.env 中的 DATABASE_URL
if [ -n "$MYSQL_URL" ]; then
  echo "替换数据库连接为 MySQL"
  sed -i "s|^DATABASE_URL=.*|DATABASE_URL=\"$MYSQL_URL\"|" /app.env
fi

# 替换 schema.prisma 中的数据库类型
if [ -f "/app/prisma/schema.prisma" ]; then
  echo "更新 Prisma 数据库类型为 MySQL"
  sed -i "s|provider = \"sqlite\"|provider = \"mysql\"|" /app/prisma/schema.prisma
  sed -i "s|url = env(\"DATABASE_URL\")|url = env(\"DATABASE_URL\")\n  relationMode = \"prisma\"|" /app/prisma/schema.prisma
fi

# 构建应用
echo "开始构建应用..."
pnpm build

# 启动应用
echo "应用构建完成，正在启动..."
pnpm start-docker