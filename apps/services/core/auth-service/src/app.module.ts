import { Module } from '@nestjs/common';
import { HealthController } from './api/http/controllers/health.controller';

@Module({
  imports: [], 
  controllers: [HealthController],
  providers: [],
})
export class AppModule {}