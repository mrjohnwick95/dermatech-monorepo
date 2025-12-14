import { IsString, MinLength, IsNotEmpty, IsEnum, IsEmail } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

//Nosotros definimos los roles del sistema
export enum UserRole {
  ADMIN = 'ADMIN',
  DOCTOR = 'DOCTOR',
  PATIENT = 'PATIENT',
}

export class RegisterDto {
  @ApiProperty({ example: 'dr_strange', description: 'Nombre de usuario único' })
  @IsString()
  @IsNotEmpty()
  username!: string;

  @ApiProperty({ example: 'doctor@dermatech.com', description: 'Email válido' })
  @IsString()
  @IsNotEmpty()
  @IsEmail({}, { message: 'El formato del email es incorrecto' })
  email!: string;

  @ApiProperty({ example: 'medicina123', description: 'Contraseña segura' })
  @IsString()
  @MinLength(6, { message: 'Mínimo 6 caracteres' })
  password!: string;

  @ApiProperty({ 
    enum: UserRole, 
    example: UserRole.PATIENT, 
    description: 'Rol del usuario (ADMIN, DOCTOR, PATIENT)' 
  })
  @IsEnum(UserRole, { message: 'El rol no es válido' })
  role!: UserRole;
}